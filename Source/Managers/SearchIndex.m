#import "SearchIndex.h"
#import "Models/Comic.h"

@interface SearchIndex ()
@property (nonatomic, assign) sqlite3 *database;
@property (nonatomic, strong) NSString *databasePath;
@end

@implementation SearchIndex

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *dir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/search"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        self.databasePath = [dir stringByAppendingPathComponent:@"search_index.sqlite"];
        int result = sqlite3_open([self.databasePath UTF8String], &_database);
        if (result == SQLITE_OK) {
            // Performance pragmas per STORAGE.md - use serialized threading mode by default
            sqlite3_exec(self.database, "PRAGMA journal_mode=DELETE; PRAGMA synchronous=NORMAL; PRAGMA cache_size=-2048; PRAGMA temp_store=MEMORY;", NULL, NULL, NULL);

            const char *tableSql = "CREATE TABLE IF NOT EXISTS search_index (id INTEGER PRIMARY KEY AUTOINCREMENT, term TEXT NOT NULL, comic_id INTEGER NOT NULL);";
            char *errMsg = NULL;
            @synchronized(self) {
                sqlite3_exec(self.database, tableSql, NULL, NULL, &errMsg);
                if (errMsg) { sqlite3_free(errMsg); errMsg = NULL; }

                const char *idxTermSql = "CREATE INDEX IF NOT EXISTS idx_search_term ON search_index(term);";
                sqlite3_exec(self.database, idxTermSql, NULL, NULL, &errMsg);
                if (errMsg) { sqlite3_free(errMsg); errMsg = NULL; }

                const char *idxComicSql = "CREATE INDEX IF NOT EXISTS idx_search_comic ON search_index(comic_id);";
                sqlite3_exec(self.database, idxComicSql, NULL, NULL, &errMsg);
                if (errMsg) { sqlite3_free(errMsg); errMsg = NULL; }

                const char *uniqueSql = "CREATE UNIQUE INDEX IF NOT EXISTS idx_search_unique ON search_index(term, comic_id);";
                sqlite3_exec(self.database, uniqueSql, NULL, NULL, &errMsg);
                if (errMsg) { sqlite3_free(errMsg); errMsg = NULL; }

                const char *legacyIdx = "CREATE INDEX IF NOT EXISTS idx_term ON search_index(term);";
                sqlite3_exec(self.database, legacyIdx, NULL, NULL, NULL);
            }
        } else {
            NSLog(@"[SearchIndex] Failed to open database at %@, result %d", self.databasePath, result);
        }
    }
    return self;
}

- (NSArray *)tokenizeText:(NSString *)text {
    if (!text || text.length == 0) return [NSArray array];
    NSString *lower = [text lowercaseString];
    NSArray *rawComponents = [lower componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *tokens = [NSMutableArray array];
    NSCharacterSet *punctuation = [NSCharacterSet punctuationCharacterSet];
    NSCharacterSet *alphanum = [NSCharacterSet alphanumericCharacterSet];

    for (NSString *raw in rawComponents) {
        if (raw.length == 0) continue;
        // Keep numbers even if short
        BOOL isNumber = YES;
        for (NSUInteger i = 0; i < raw.length; i++) {
            unichar c = [raw characterAtIndex:i];
            if (c < '0' || c > '9') {
                isNumber = NO;
                break;
            }
        }
        if (isNumber) {
            if (raw.length >= 1) {
                [tokens addObject:raw];
            }
            continue;
        }

        NSString *trimmed = [raw stringByTrimmingCharactersInSet:punctuation];
        NSMutableString *filtered = [NSMutableString string];
        for (NSUInteger i = 0; i < trimmed.length; i++) {
            unichar c = [trimmed characterAtIndex:i];
            if ([alphanum characterIsMember:c] || c == '\'') {
                [filtered appendFormat:@"%C", c];
            }
        }
        NSString *token = [filtered stringByTrimmingCharactersInSet:punctuation];
        if (token.length >= 2) {
            // Don't filter stop words for search - keep them for FindXKCD-like behavior
            // Previously filtered the, and, for, you, are - now keep all >=2 chars
            [tokens addObject:token];
        }
    }
    NSSet *unique = [NSSet setWithArray:tokens];
    return [unique allObjects];
}

- (NSArray *)resultsForQuery:(NSString *)query {
    @synchronized(self) {
        NSMutableArray *results = [NSMutableArray array];
        if (!self.database) return results;
        if (!query || query.length == 0) return results;

        NSString *trimmed = [query lowercaseString];
        trimmed = [trimmed stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) return results;

        // If query is numeric, return that comic ID directly as well (for FindXKCD-like number search)
        // We'll handle numeric search in SearchManager, but also add to token search here

        NSArray *queryTokens = [self tokenizeText:trimmed];
        if ([queryTokens count] == 0) {
            queryTokens = @[trimmed];
        }

        // Build query with OR for each token, using LIKE for substring match
        NSMutableString *sqlBuilder = [NSMutableString stringWithString:@"SELECT DISTINCT comic_id FROM search_index WHERE "];
        for (NSUInteger i = 0; i < [queryTokens count]; i++) {
            if (i > 0) [sqlBuilder appendString:@" OR "];
            [sqlBuilder appendString:@"term LIKE ?"];
        }
        [sqlBuilder appendString:@" ORDER BY comic_id DESC LIMIT 100;"];

        const char *sql = [sqlBuilder UTF8String];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.database, sql, -1, &stmt, NULL) == SQLITE_OK) {
            for (NSUInteger i = 0; i < [queryTokens count]; i++) {
                NSString *token = [queryTokens objectAtIndex:i];
                NSString *likePattern = [NSString stringWithFormat:@"%%%@%%", token];
                sqlite3_bind_text(stmt, (int)(i+1), [likePattern UTF8String], -1, SQLITE_TRANSIENT);
            }
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                int comicId = sqlite3_column_int(stmt, 0);
                if (comicId > 0) {
                    [results addObject:@(comicId)];
                }
            }
            sqlite3_finalize(stmt);
        } else {
            NSLog(@"[SearchIndex] Failed to prepare query: %s for SQL: %@", sqlite3_errmsg(self.database), sqlBuilder);
        }
        return results;
    }
}

- (void)rebuildIndex:(NSArray *)comics {
    @synchronized(self) {
        if (!self.database) return;
        char *errMsg = NULL;
        sqlite3_exec(self.database, "BEGIN TRANSACTION;", NULL, NULL, &errMsg);
        if (errMsg) { sqlite3_free(errMsg); errMsg = NULL; }

        sqlite3_exec(self.database, "DELETE FROM search_index;", NULL, NULL, &errMsg);
        if (errMsg) { sqlite3_free(errMsg); errMsg = NULL; }

        for (Comic *comic in comics) {
            [self addComicInternal:comic];
        }

        sqlite3_exec(self.database, "COMMIT;", NULL, NULL, &errMsg);
        if (errMsg) { sqlite3_free(errMsg); errMsg = NULL; }
        // Don't VACUUM inside transaction, and avoid WAL issues - skip VACUUM for now
    }
}

- (void)addComicInternal:(Comic *)comic {
    // Must be called inside @synchronized(self) or from addComic which synchronizes
    if (!self.database || !comic) return;
    if (comic.number <= 0) return;
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@ %ld",
                          comic.title ? comic.title : @"",
                          comic.altText ? comic.altText : @"",
                          comic.transcript ? comic.transcript : @"",
                          comic.dateString ? comic.dateString : @"",
                          (long)comic.number];
    NSArray *tokens = [self tokenizeText:combined];
    for (NSString *token in tokens) {
        const char *sql = "INSERT OR IGNORE INTO search_index (term, comic_id) VALUES (?, ?);";
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.database, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, [token UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_int(stmt, 2, (int)comic.number);
            sqlite3_step(stmt);
            sqlite3_finalize(stmt);
        }
    }
}

- (void)addComic:(Comic *)comic {
    @synchronized(self) {
        if (!self.database || !comic) return;
        if (comic.number <= 0) return;
        // Remove existing entries for this comic to avoid stale terms
        [self removeComicInternal:comic];
        [self addComicInternal:comic];
    }
}

- (void)removeComicInternal:(Comic *)comic {
    if (!self.database || !comic) return;
    const char *sql = "DELETE FROM search_index WHERE comic_id = ?;";
    sqlite3_stmt *stmt = NULL;
    if (sqlite3_prepare_v2(self.database, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int(stmt, 1, (int)comic.number);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
}

- (void)removeComic:(Comic *)comic {
    @synchronized(self) {
        [self removeComicInternal:comic];
    }
}

- (void)close {
    @synchronized(self) {
        if (self.database) {
            sqlite3_close(self.database);
            self.database = NULL;
        }
    }
}

- (void)dealloc {
    [self close];
}

@end

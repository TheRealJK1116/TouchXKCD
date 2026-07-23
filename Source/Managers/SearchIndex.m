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
            const char *sql = "CREATE TABLE IF NOT EXISTS search_index (term TEXT, comic_id INTEGER); CREATE INDEX IF NOT EXISTS idx_term ON search_index(term);";
            char *errMsg = NULL;
            sqlite3_exec(self.database, sql, NULL, NULL, &errMsg);
            if (errMsg) sqlite3_free(errMsg);
        }
    }
    return self;
}

- (NSArray *)tokenizeText:(NSString *)text {
    if (!text || text.length == 0) return [NSArray array];
    NSCharacterSet *punctuation = [NSCharacterSet punctuationCharacterSet];
    NSString *clean = [[text lowercaseString] stringByTrimmingCharactersInSet:punctuation];
    NSArray *components = [clean componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSString *token in components) {
        if (token.length >= 2) {
            [tokens addObject:token];
        }
    }
    return tokens;
}

- (NSArray *)resultsForQuery:(NSString *)query {
    NSMutableArray *results = [NSMutableArray array];
    if (!self.database) return results;
    NSString *likePattern = [NSString stringWithFormat:@"%%%@%%", [query lowercaseString]];
    const char *sql = "SELECT DISTINCT comic_id FROM search_index WHERE term LIKE ?;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(self.database, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [likePattern UTF8String], -1, SQLITE_TRANSIENT);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            int comicId = sqlite3_column_int(stmt, 0);
            [results addObject:[NSNumber numberWithInt:comicId]];
        }
        sqlite3_finalize(stmt);
    }
    return results;
}

- (void)rebuildIndex:(NSArray *)comics {
    if (!self.database) return;
    const char *clearSql = "DELETE FROM search_index;";
    sqlite3_exec(self.database, clearSql, NULL, NULL, NULL);
    for (Comic *comic in comics) {
        [self addComic:comic];
    }
}

- (void)addComic:(Comic *)comic {
    if (!self.database || !comic) return;
    NSArray *tokens = [self tokenizeText:[NSString stringWithFormat:@"%@ %@ %@", comic.title ? comic.title : @"", comic.altText ? comic.altText : @"", comic.transcript ? comic.transcript : @""]];
    for (NSString *token in tokens) {
        const char *sql = "INSERT OR IGNORE INTO search_index (term, comic_id) VALUES (?, ?);";
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(self.database, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, [token UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_int(stmt, 2, (int)comic.number);
            sqlite3_step(stmt);
            sqlite3_finalize(stmt);
        }
    }
}

- (void)removeComic:(Comic *)comic {
    if (!self.database || !comic) return;
    const char *sql = "DELETE FROM search_index WHERE comic_id = ?;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(self.database, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_int(stmt, 1, (int)comic.number);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
}

- (void)close {
    if (self.database) {
        sqlite3_close(self.database);
        self.database = NULL;
    }
}

- (void)dealloc {
    [self close];
}

@end

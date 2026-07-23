#import "SearchManager.h"
#import "Managers/SearchIndex.h"
#import "Managers/StorageManager.h"
#import "Managers/ExplanationCache.h"
#import "Models/Comic.h"
#import "Models/Explanation.h"

@interface SearchManager ()
@property (nonatomic, strong) SearchIndex *searchIndex;
@end

@implementation SearchManager

+ (instancetype)sharedManager {
    static SearchManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.searchIndex = [[SearchIndex alloc] init];
        // Rebuild on first launch in background to avoid blocking main thread
        // Use low priority to not interfere with initial comic fetch
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [shared rebuildSearchIndex];
        });
    });
    return shared;
}

- (NSArray *)searchResults:(NSString *)query {
    if (!query || query.length == 0) {
        return [NSArray array];
    }
    NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return [NSArray array];
    }

    NSMutableArray *results = [NSMutableArray array];
    NSMutableSet *addedNumbers = [NSMutableSet set];

    // 1. Numeric search: if query is a number, try to load that comic directly (FindXKCD-like jump)
    // Also handle "#123" or "123" patterns
    NSString *numericPart = trimmed;
    if ([numericPart hasPrefix:@"#"]) {
        numericPart = [numericPart substringFromIndex:1];
    }
    NSInteger numberQuery = [numericPart integerValue];
    if (numberQuery > 0 && [numericPart rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
        Comic *byNumber = [[StorageManager sharedManager] loadComic:numberQuery];
        if (byNumber) {
            [results addObject:byNumber];
            [addedNumbers addObject:@(byNumber.number)];
        } else {
            // Even if not cached, try to return a placeholder comic object for navigation?
            // For offline search, we only return cached, but we can include number as result for future fetch
            // Here we skip if not cached to keep offline behavior
        }
    }

    // 2. SQLite index search
    NSArray *comicIds = [self.searchIndex resultsForQuery:trimmed];
    for (NSNumber *num in comicIds) {
        if (!num) continue;
        NSInteger comicNumber = [num integerValue];
        if (comicNumber <= 0) continue;
        if ([addedNumbers containsObject:num]) continue;
        Comic *comic = [[StorageManager sharedManager] loadComic:comicNumber];
        if (comic) {
            [results addObject:comic];
            [addedNumbers addObject:num];
        }
    }

    // 3. Fallback linear scan if index returned nothing or few results (for robustness)
    // This ensures search works even if SQLite index is empty or corrupted - FindXKCD-like linear search
    if ([results count] < 5) {
        NSArray *allCached = [[StorageManager sharedManager] loadAllComics];
        NSString *lowerQuery = [trimmed lowercaseString];
        for (Comic *comic in allCached) {
            if ([addedNumbers containsObject:@(comic.number)]) continue;
            BOOL matches = NO;
            if (comic.title && [[comic.title lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
            else if (comic.altText && [[comic.altText lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
            else if (comic.transcript && [[comic.transcript lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
            else if (comic.dateString && [[comic.dateString lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
            else {
                // Check explanation if cached
                Explanation *exp = [[ExplanationCache sharedCache] cachedExplanationForComic:comic.number];
                if (exp) {
                    if (exp.body && [[exp.body lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
                    else if (exp.transcript && [[exp.transcript lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
                }
            }
            if (matches) {
                [results addObject:comic];
                [addedNumbers addObject:@(comic.number)];
                if ([results count] >= 50) break;
            }
        }
    }

    // Sort by number descending for recency (newest first) - FindXKCD style
    [results sortUsingComparator:^NSComparisonResult(Comic *a, Comic *b) {
        if (a.number > b.number) return NSOrderedAscending; // Descending: larger number first
        if (a.number < b.number) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    if ([results count] > 50) {
        return [results subarrayWithRange:NSMakeRange(0, 50)];
    }
    return [results copy];
}

- (void)addComicToIndex:(Comic *)comic {
    if (!comic) return;
    if (comic.number <= 0) return;
    [self.searchIndex addComic:comic];

    // Also index explanation and wiki transcript if cached (for FindXKCD-like search)
    Explanation *exp = [[ExplanationCache sharedCache] cachedExplanationForComic:comic.number];
    if (exp && (exp.body.length > 0 || exp.transcript.length > 0)) {
        Comic *combined = [[Comic alloc] init];
        combined.number = comic.number;
        combined.title = comic.title;
        NSString *extra = @"";
        if (exp.body) extra = [extra stringByAppendingFormat:@" %@ ", exp.body];
        if (exp.transcript) extra = [extra stringByAppendingFormat:@" %@ ", exp.transcript];
        combined.altText = [NSString stringWithFormat:@"%@ %@", comic.altText ?: @"", extra];
        combined.transcript = [NSString stringWithFormat:@"%@ %@", comic.transcript ?: @"", extra];
        combined.dateString = comic.dateString;
        [self.searchIndex addComic:combined];
    }
}

- (void)rebuildSearchIndex {
    NSArray *cachedComics = [[StorageManager sharedManager] loadAllComics];
    NSLog(@"[SearchManager] Rebuilding index from %lu cached comics", (unsigned long)[cachedComics count]);
    [self.searchIndex rebuildIndex:cachedComics];

    // After rebuilding base index, also add explanation terms for each cached comic
    for (Comic *comic in cachedComics) {
        Explanation *exp = [[ExplanationCache sharedCache] cachedExplanationForComic:comic.number];
        if (exp && (exp.body.length > 0 || exp.transcript.length > 0)) {
            Comic *combined = [[Comic alloc] init];
            combined.number = comic.number;
            combined.title = comic.title;
            NSString *extra = @"";
            if (exp.body) extra = [extra stringByAppendingFormat:@" %@ ", exp.body];
            if (exp.transcript) extra = [extra stringByAppendingFormat:@" %@ ", exp.transcript];
            combined.altText = [NSString stringWithFormat:@"%@ %@", comic.altText ?: @"", extra];
            combined.transcript = [NSString stringWithFormat:@"%@ %@", comic.transcript ?: @"", extra];
            combined.dateString = comic.dateString;
            [self.searchIndex addComic:combined];
        }
    }
    NSLog(@"[SearchManager] Rebuild complete");
}

- (void)removeComicFromIndex:(Comic *)comic {
    if (!comic) return;
    [self.searchIndex removeComic:comic];
}

@end

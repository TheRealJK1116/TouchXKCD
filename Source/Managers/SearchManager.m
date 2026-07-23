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
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            @try {
                [shared rebuildSearchIndex];
            } @catch (NSException *ex) {
                NSLog(@"[SearchManager] Rebuild crashed: %@", ex);
            }
        });
    });
    return shared;
}

- (NSArray *)searchResults:(NSString *)query {
    @try {
        if (!query || query.length == 0) {
            return [NSArray array];
        }
        NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) {
            return [NSArray array];
        }

        NSMutableArray *results = [NSMutableArray array];
        NSMutableSet *addedNumbers = [NSMutableSet set];

        // 1. Numeric search: handle "#123" or "123" - return even if not cached (tap to fetch)
        NSString *numericPart = trimmed;
        if ([numericPart hasPrefix:@"#"]) {
            numericPart = [numericPart substringFromIndex:1];
        }
        // Check if numericPart is purely digits
        NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        if (numericPart.length > 0 && [numericPart rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
            NSInteger numberQuery = [numericPart integerValue];
            if (numberQuery > 0 && numberQuery < 10000) { // Reasonable upper bound
                Comic *byNumber = [[StorageManager sharedManager] loadComic:numberQuery];
                if (byNumber) {
                    [results addObject:byNumber];
                    [addedNumbers addObject:@(byNumber.number)];
                } else {
                    // Return synthetic comic for non-cached number - user can tap to fetch (FindXKCD-like)
                    Comic *synthetic = [Comic comicWithNumber:numberQuery];
                    synthetic.title = [NSString stringWithFormat:@"Comic #%ld (Not cached - tap to fetch)", (long)numberQuery];
                    synthetic.dateString = @"Tap to load";
                    // Mark as synthetic by having empty imageURL but valid number
                    [results addObject:synthetic];
                    [addedNumbers addObject:@(numberQuery)];
                    // Don't return immediately - also do word search for other matches
                }
            }
        }

        // 2. SQLite index search - wrapped in try/catch to prevent crash
        NSArray *comicIds = nil;
        @try {
            comicIds = [self.searchIndex resultsForQuery:trimmed];
        } @catch (NSException *ex) {
            NSLog(@"[SearchManager] SearchIndex crashed: %@, query: %@", ex, trimmed);
            comicIds = [NSArray array];
        }

        for (NSNumber *num in comicIds) {
            @try {
                if (!num) continue;
                NSInteger comicNumber = [num integerValue];
                if (comicNumber <= 0) continue;
                if ([addedNumbers containsObject:num]) continue;
                Comic *comic = [[StorageManager sharedManager] loadComic:comicNumber];
                if (comic) {
                    [results addObject:comic];
                    [addedNumbers addObject:num];
                }
                if ([results count] >= 50) break;
            } @catch (NSException *ex) {
                NSLog(@"[SearchManager] Exception loading comic from index: %@", ex);
                continue;
            }
        }

        // 3. Fallback linear scan if index returned few results - FindXKCD-like offline scan
        // Only do this if we have less than 10 results and query is at least 2 chars
        // Limit scanning to avoid memory crash on low-RAM device (iPod touch 4G 256MB)
        if ([results count] < 10 && trimmed.length >= 2) {
            @try {
                NSArray *allCached = [[StorageManager sharedManager] loadAllComics];
                // Limit to most recent 200 comics for memory safety
                NSArray *scanSet = allCached;
                if ([allCached count] > 200) {
                    // Sort by number descending and take first 200
                    NSArray *sorted = [allCached sortedArrayUsingComparator:^NSComparisonResult(Comic *a, Comic *b) {
                        if (a.number > b.number) return NSOrderedAscending;
                        if (a.number < b.number) return NSOrderedDescending;
                        return NSOrderedSame;
                    }];
                    scanSet = [sorted subarrayWithRange:NSMakeRange(0, 200)];
                }

                NSString *lowerQuery = [trimmed lowercaseString];
                for (Comic *comic in scanSet) {
                    @autoreleasepool {
                        if ([addedNumbers containsObject:@(comic.number)]) continue;
                        BOOL matches = NO;
                        if (comic.title && [[comic.title lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
                        else if (comic.altText && [[comic.altText lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
                        else if (comic.transcript && [[comic.transcript lowercaseString] rangeOfString:lowerQuery].location != NSNotFound) matches = YES;
                        else {
                            // Check explanation only if previous checks failed to save I/O
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
            } @catch (NSException *ex) {
                NSLog(@"[SearchManager] Fallback scan crashed: %@", ex);
            }
        }

        // Sort by number descending (newest first) - FindXKCD style
        @try {
            [results sortUsingComparator:^NSComparisonResult(Comic *a, Comic *b) {
                if (a.number > b.number) return NSOrderedAscending;
                if (a.number < b.number) return NSOrderedDescending;
                return NSOrderedSame;
            }];
        } @catch (NSException *ex) {
            NSLog(@"[SearchManager] Sort crashed: %@", ex);
        }

        if ([results count] > 50) {
            return [results subarrayWithRange:NSMakeRange(0, 50)];
        }
        return [results copy];
    } @catch (NSException *ex) {
        NSLog(@"[SearchManager] searchResults crashed for query %@: %@", query, ex);
        return [NSArray array];
    }
}

- (void)addComicToIndex:(Comic *)comic {
    if (!comic) return;
    if (comic.number <= 0) return;
    @try {
        [self.searchIndex addComic:comic];
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
    } @catch (NSException *ex) {
        NSLog(@"[SearchManager] addComicToIndex crashed: %@", ex);
    }
}

- (void)rebuildSearchIndex {
    @try {
        NSArray *cachedComics = [[StorageManager sharedManager] loadAllComics];
        NSLog(@"[SearchManager] Rebuilding index from %lu cached comics", (unsigned long)[cachedComics count]);
        [self.searchIndex rebuildIndex:cachedComics];
        for (Comic *comic in cachedComics) {
            @autoreleasepool {
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
        }
        NSLog(@"[SearchManager] Rebuild complete");
    } @catch (NSException *ex) {
        NSLog(@"[SearchManager] rebuildSearchIndex crashed: %@", ex);
    }
}

- (void)removeComicFromIndex:(Comic *)comic {
    if (!comic) return;
    @try {
        [self.searchIndex removeComic:comic];
    } @catch (NSException *ex) {
        NSLog(@"[SearchManager] removeComicFromIndex crashed: %@", ex);
    }
}

@end

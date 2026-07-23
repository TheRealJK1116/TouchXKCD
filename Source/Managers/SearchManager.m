#import "SearchManager.h"
#import "Managers/SearchIndex.h"
#import "Managers/StorageManager.h"

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
    });
    return shared;
}

- (NSArray *)searchResults:(NSString *)query {
    NSArray *comicIds = [self.searchIndex resultsForQuery:query];
    NSMutableArray *results = [NSMutableArray array];
    for (NSNumber *num in comicIds) {
        Comic *comic = [[StorageManager sharedManager] loadComic:[num intValue]];
        if (comic) {
            [results addObject:comic];
        }
    }
    return results;
}

- (void)addComicToIndex:(Comic *)comic {
    [self.searchIndex addComic:comic];
}

- (void)rebuildSearchIndex {
    NSArray *cachedComics = [[StorageManager sharedManager] loadAllComics];
    [self.searchIndex rebuildIndex:cachedComics];
}

@end

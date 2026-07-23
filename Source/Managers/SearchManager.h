#import <Foundation/Foundation.h>

@class Comic;

@interface SearchManager : NSObject

+ (instancetype)sharedManager;
- (NSArray *)searchResults:(NSString *)query;
- (void)rebuildSearchIndex;
- (void)addComicToIndex:(Comic *)comic;
- (void)removeComicFromIndex:(Comic *)comic;

@end

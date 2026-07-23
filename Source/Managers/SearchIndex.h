#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class Comic;

@interface SearchIndex : NSObject

- (instancetype)init;
- (NSArray *)resultsForQuery:(NSString *)query;
- (void)rebuildIndex:(NSArray *)comics;
- (void)addComic:(Comic *)comic;
- (void)removeComic:(Comic *)comic;
- (void)close;

@end

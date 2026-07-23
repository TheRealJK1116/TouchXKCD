#import <Foundation/Foundation.h>

@class Comic;

@protocol ComicNetworkDelegate <NSObject>
- (void)comicFetched:(Comic *)comic;
- (void)comicFetchFailed:(NSInteger)number error:(NSError *)error;
@end

@protocol ComicNetworkProtocol <NSObject>
- (void)fetchComic:(NSInteger)number delegate:(id<ComicNetworkDelegate>)delegate;
@end

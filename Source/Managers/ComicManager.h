#import <Foundation/Foundation.h>
#import "Protocols/ComicNetworkProtocol.h"
#import "Managers/XKCDNetworkClient.h"

@class Comic;

@interface ComicManager : NSObject <ComicNetworkProtocol, XKCDNetworkClientDelegate>

+ (instancetype)sharedManager;
- (void)fetchComic:(NSInteger)number delegate:(id<ComicNetworkDelegate>)delegate;
- (void)fetchLatestComic:(id<ComicNetworkDelegate>)delegate;
- (void)fetchRandomComic:(id<ComicNetworkDelegate>)delegate;
- (void)fetchPreviousComic:(NSInteger)currentNumber delegate:(id<ComicNetworkDelegate>)delegate;
- (void)fetchNextComic:(NSInteger)currentNumber delegate:(id<ComicNetworkDelegate>)delegate;
- (Comic *)cachedComic:(NSInteger)number;

@end

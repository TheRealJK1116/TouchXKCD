#import <Foundation/Foundation.h>

@class Comic;

@protocol XKCDNetworkClientDelegate <NSObject>
- (void)networkClient:(id)client didFetchComic:(Comic *)comic error:(NSError *)error;
- (void)networkClient:(id)client didFetchImageData:(NSData *)data forComic:(NSInteger)comicNumber error:(NSError *)error;
@end

@interface XKCDNetworkClient : NSObject <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

+ (instancetype)sharedClient;

- (void)fetchComicWithNumber:(NSInteger)number delegate:(id<XKCDNetworkClientDelegate>)delegate;
- (void)fetchLatestComicWithDelegate:(id<XKCDNetworkClientDelegate>)delegate;
- (void)fetchRandomComicWithDelegate:(id<XKCDNetworkClientDelegate>)delegate;
- (void)fetchImageForComic:(NSInteger)comicNumber imageURLString:(NSString *)urlString delegate:(id<XKCDNetworkClientDelegate>)delegate;
- (void)cancelAllRequests;

@end

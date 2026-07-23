#import "XKCDNetworkClient.h"
#import "Models/Comic.h"

@interface RequestInfo : NSObject
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, assign) id<XKCDNetworkClientDelegate> delegate;
@property (nonatomic, assign) BOOL isImageRequest;
@end

@implementation RequestInfo
@end

@interface XKCDNetworkClient ()
@property (nonatomic, strong) NSMutableDictionary *connectionMap;
@end

@implementation XKCDNetworkClient

+ (instancetype)sharedClient {
    static XKCDNetworkClient *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.connectionMap = [NSMutableDictionary dictionary];
    });
    return shared;
}

- (void)fetchComicWithNumber:(NSInteger)number delegate:(id<XKCDNetworkClientDelegate>)delegate {
    NSString *urlString = (number > 0) ? [NSString stringWithFormat:@"https://xkcd.com/%ld/info.0.json", (long)number] : @"https://xkcd.com/info.0.json";
    [self startRequestWithURLString:urlString comicNumber:number delegate:delegate isImage:NO];
}

- (void)fetchLatestComicWithDelegate:(id<XKCDNetworkClientDelegate>)delegate {
    [self startRequestWithURLString:@"https://xkcd.com/info.0.json" comicNumber:0 delegate:delegate isImage:NO];
}

- (void)fetchRandomComicWithDelegate:(id<XKCDNetworkClientDelegate>)delegate {
    // Random: we'll fetch latest first, then pick a random number between 1 and latest number.
    // For simplicity, this skeleton delegates to latest and lets the manager handle randomness.
    [self fetchLatestComicWithDelegate:delegate];
}

- (void)fetchImageForComic:(NSInteger)comicNumber imageURLString:(NSString *)urlString delegate:(id<XKCDNetworkClientDelegate>)delegate {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection) {
        RequestInfo *info = [[RequestInfo alloc] init];
        info.responseData = [NSMutableData data];
        info.comicNumber = comicNumber;
        info.delegate = delegate;
        info.isImageRequest = YES;
        [self.connectionMap setObject:info forKey:[NSValue valueWithNonretainedObject:connection]];
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [connection start];
    }
}

- (void)startRequestWithURLString:(NSString *)urlString comicNumber:(NSInteger)number delegate:(id<XKCDNetworkClientDelegate>)delegate isImage:(BOOL)isImage {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection) {
        RequestInfo *info = [[RequestInfo alloc] init];
        info.responseData = [NSMutableData data];
        info.comicNumber = number;
        info.delegate = delegate;
        info.isImageRequest = isImage;
        [self.connectionMap setObject:info forKey:[NSValue valueWithNonretainedObject:connection]];
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [connection start];
    }
}

- (void)cancelAllRequests {
    NSArray *keys = [self.connectionMap allKeys];
    for (NSValue *key in keys) {
        NSURLConnection *connection = [key nonretainedObjectValue];
        [connection cancel];
    }
    [self.connectionMap removeAllObjects];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSValue *key = [NSValue valueWithNonretainedObject:connection];
    RequestInfo *info = [self.connectionMap objectForKey:key];
    [info.responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSValue *key = [NSValue valueWithNonretainedObject:connection];
    RequestInfo *info = [self.connectionMap objectForKey:key];
    [info.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSValue *key = [NSValue valueWithNonretainedObject:connection];
    RequestInfo *info = [self.connectionMap objectForKey:key];
    [self.connectionMap removeObjectForKey:key];
    if (!info) return;

    if (info.isImageRequest) {
        if ([info.delegate respondsToSelector:@selector(networkClient:didFetchImageData:forComic:error:)]) {
            [info.delegate networkClient:self didFetchImageData:info.responseData forComic:info.comicNumber error:nil];
        }
    } else {
        NSError *parseError = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:info.responseData options:0 error:&parseError];
        if (!parseError && jsonDict) {
            Comic *comic = [[Comic alloc] init];
            [comic hydrateFromDictionary:jsonDict];
            if ([info.delegate respondsToSelector:@selector(networkClient:didFetchComic:error:)]) {
                [info.delegate networkClient:self didFetchComic:comic error:nil];
            }
        } else {
            if ([info.delegate respondsToSelector:@selector(networkClient:didFetchComic:error:)]) {
                [info.delegate networkClient:self didFetchComic:nil error:parseError ? parseError : [NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse JSON"}]];
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSValue *key = [NSValue valueWithNonretainedObject:connection];
    RequestInfo *info = [self.connectionMap objectForKey:key];
    [self.connectionMap removeObjectForKey:key];
    if (!info) return;

    if (info.isImageRequest) {
        if ([info.delegate respondsToSelector:@selector(networkClient:didFetchImageData:forComic:error:)]) {
            [info.delegate networkClient:self didFetchImageData:nil forComic:info.comicNumber error:error];
        }
    } else {
        if ([info.delegate respondsToSelector:@selector(networkClient:didFetchComic:error:)]) {
            [info.delegate networkClient:self didFetchComic:nil error:error];
        }
    }
}

@end

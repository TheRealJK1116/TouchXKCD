#import "XKCDNetworkClient.h"
#import "Models/Comic.h"

@interface RequestInfo : NSObject
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, assign) id<XKCDNetworkClientDelegate> delegate;
@property (nonatomic, assign) BOOL isImageRequest;
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation RequestInfo
@end

@interface XKCDNetworkClient () <NSURLConnectionDataDelegate, NSURLConnectionDelegate>
@property (nonatomic, strong) NSMutableDictionary *connectionMap; // key: NSValue(connection), value: RequestInfo
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
    // For proper random handling, ComicManager now implements randomness; this remains for backward compat
    [self fetchLatestComicWithDelegate:delegate];
}

- (void)fetchImageForComic:(NSInteger)comicNumber imageURLString:(NSString *)urlString delegate:(id<XKCDNetworkClientDelegate>)delegate {
    if (!urlString || urlString.length == 0) {
        if ([delegate respondsToSelector:@selector(networkClient:didFetchImageData:forComic:error:)]) {
            [delegate networkClient:self didFetchImageData:nil forComic:comicNumber error:[NSError errorWithDomain:@"TouchXKCD" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid image URL"}]];
        }
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if ([delegate respondsToSelector:@selector(networkClient:didFetchImageData:forComic:error:)]) {
            [delegate networkClient:self didFetchImageData:nil forComic:comicNumber error:[NSError errorWithDomain:@"TouchXKCD" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL format"}]];
        }
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection) {
        RequestInfo *info = [[RequestInfo alloc] init];
        info.responseData = [NSMutableData data];
        info.comicNumber = comicNumber;
        info.delegate = delegate;
        info.isImageRequest = YES;
        info.connection = connection;
        @synchronized(self.connectionMap) {
            [self.connectionMap setObject:info forKey:[NSValue valueWithNonretainedObject:connection]];
        }
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [connection start];
    } else {
        if ([delegate respondsToSelector:@selector(networkClient:didFetchImageData:forComic:error:)]) {
            [delegate networkClient:self didFetchImageData:nil forComic:comicNumber error:[NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create connection"}]];
        }
    }
}

- (void)startRequestWithURLString:(NSString *)urlString comicNumber:(NSInteger)number delegate:(id<XKCDNetworkClientDelegate>)delegate isImage:(BOOL)isImage {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if ([delegate respondsToSelector:@selector(networkClient:didFetchComic:error:)]) {
            [delegate networkClient:self didFetchComic:nil error:[NSError errorWithDomain:@"TouchXKCD" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]];
        }
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection) {
        RequestInfo *info = [[RequestInfo alloc] init];
        info.responseData = [NSMutableData data];
        info.comicNumber = number;
        info.delegate = delegate;
        info.isImageRequest = isImage;
        info.connection = connection;
        @synchronized(self.connectionMap) {
            [self.connectionMap setObject:info forKey:[NSValue valueWithNonretainedObject:connection]];
        }
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [connection start];
    } else {
        if ([delegate respondsToSelector:@selector(networkClient:didFetchComic:error:)]) {
            [delegate networkClient:self didFetchComic:nil error:[NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create connection"}]];
        }
    }
}

- (void)cancelAllRequests {
    @synchronized(self.connectionMap) {
        for (NSValue *key in [self.connectionMap allKeys]) {
            RequestInfo *info = [self.connectionMap objectForKey:key];
            [info.connection cancel];
        }
        [self.connectionMap removeAllObjects];
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (RequestInfo *)infoForConnection:(NSURLConnection *)connection {
    @synchronized(self.connectionMap) {
        return [self.connectionMap objectForKey:[NSValue valueWithNonretainedObject:connection]];
    }
}

- (void)removeInfoForConnection:(NSURLConnection *)connection {
    @synchronized(self.connectionMap) {
        [self.connectionMap removeObjectForKey:[NSValue valueWithNonretainedObject:connection]];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    RequestInfo *info = [self infoForConnection:connection];
    [info.responseData setLength:0];
    // Check HTTP status code if HTTP response
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode >= 400) {
            // Will be handled as failure later, but log
            NSLog(@"[XKCDNetworkClient] HTTP %ld for comic %ld", (long)statusCode, (long)info.comicNumber);
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    RequestInfo *info = [self infoForConnection:connection];
    [info.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    RequestInfo *info = [self infoForConnection:connection];
    [self removeInfoForConnection:connection];
    if (!info) return;

    if (info.isImageRequest) {
        if ([info.delegate respondsToSelector:@selector(networkClient:didFetchImageData:forComic:error:)]) {
            [info.delegate networkClient:self didFetchImageData:info.responseData forComic:info.comicNumber error:nil];
        }
    } else {
        NSError *parseError = nil;
        if (info.responseData.length == 0) {
            parseError = [NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Empty response"}];
        }
        NSDictionary *jsonDict = nil;
        if (!parseError) {
            jsonDict = [NSJSONSerialization JSONObjectWithData:info.responseData options:0 error:&parseError];
        }
        if (!parseError && jsonDict) {
            Comic *comic = [[Comic alloc] init];
            @try {
                [comic hydrateFromDictionary:jsonDict];
            } @catch (NSException *ex) {
                parseError = [NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Hydration failed: %@", ex]}];
                comic = nil;
            }
            if (comic) {
                if ([info.delegate respondsToSelector:@selector(networkClient:didFetchComic:error:)]) {
                    [info.delegate networkClient:self didFetchComic:comic error:nil];
                }
            } else {
                if ([info.delegate respondsToSelector:@selector(networkClient:didFetchComic:error:)]) {
                    [info.delegate networkClient:self didFetchComic:nil error:parseError];
                }
            }
        } else {
            if ([info.delegate respondsToSelector:@selector(networkClient:didFetchComic:error:)]) {
                NSError *err = parseError ?: [NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse JSON"}];
                [info.delegate networkClient:self didFetchComic:nil error:err];
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    RequestInfo *info = [self infoForConnection:connection];
    [self removeInfoForConnection:connection];
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

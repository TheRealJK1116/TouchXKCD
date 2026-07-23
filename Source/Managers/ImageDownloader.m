#import "ImageDownloader.h"
#import "Managers/ImageCache.h"

@interface ImageRequestInfo : NSObject
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSString *urlString;
@property (nonatomic, weak) id<ImageDownloaderDelegate> delegate;
@end

@implementation ImageRequestInfo
@end

@interface ImageDownloader ()
@property (nonatomic, strong) NSMutableDictionary *downloads;
@end

@implementation ImageDownloader

+ (instancetype)sharedDownloader {
    static ImageDownloader *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.downloads = [NSMutableDictionary dictionary];
    });
    return shared;
}

- (void)downloadImageFromURL:(NSString *)urlString delegate:(id<ImageDownloaderDelegate>)delegate {
    if (!urlString || urlString.length == 0) {
        if ([delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
            [delegate imageDownloader:self didDownloadImage:nil forURL:urlString error:[NSError errorWithDomain:@"TouchXKCD" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]];
        }
        return;
    }

    UIImage *cached = [[ImageCache sharedCache] cachedImageForKey:urlString];
    if (cached) {
        if ([delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
            [delegate imageDownloader:self didDownloadImage:cached forURL:urlString error:nil];
        }
        return;
    }

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/images"];
    NSString *filename = [urlString lastPathComponent];
    NSString *filePath = [cacheDir stringByAppendingPathComponent:filename];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:filePath]) {
        UIImage *fileImage = [UIImage imageWithContentsOfFile:filePath];
        if (fileImage) {
            [[ImageCache sharedCache] cacheImage:fileImage forKey:urlString];
            if ([delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
                [delegate imageDownloader:self didDownloadImage:fileImage forURL:urlString error:nil];
            }
            return;
        }
    }

    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url URLCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection) {
        ImageRequestInfo *info = [[ImageRequestInfo alloc] init];
        info.data = [NSMutableData data];
        info.urlString = urlString;
        info.delegate = delegate;
        [self.downloads setObject:info forKey:[NSValue valueWithNonretainedObject:connection]];
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [connection start];
    }
}

- (void)cancelDownloadForURL:(NSString *)urlString {
    NSArray *keys = [self.downloads allKeys];
    for (NSValue *key in keys) {
        ImageRequestInfo *info = [self.downloads objectForKey:key];
        if ([info.urlString isEqualToString:urlString]) {
            NSURLConnection *connection = [key nonretainedObjectValue];
            [connection cancel];
            [self.downloads removeObjectForKey:key];
        }
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSValue *key = [NSValue valueWithNonretainedObject:connection];
    ImageRequestInfo *info = [self.downloads objectForKey:key];
    [info.data setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSValue *key = [NSValue valueWithNonretainedObject:connection];
    ImageRequestInfo *info = [self.downloads objectForKey:key];
    [info.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSValue *key = [NSValue valueWithNonretainedObject:connection];
    ImageRequestInfo *info = [self.downloads objectForKey:key];
    [self.downloads removeObjectForKey:key];
    if (!info) return;

    UIImage *image = [UIImage imageWithData:info.data];
    if (image) {
        [[ImageCache sharedCache] cacheImage:image forKey:info.urlString];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/images"];
        NSString *filename = [info.urlString lastPathComponent];
        NSString *filePath = [cacheDir stringByAppendingPathComponent:filename];

        NSError *writeError = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL dirCreated = YES;
        if (![fm fileExistsAtPath:cacheDir]) {
            dirCreated = [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:&writeError];
        }
        if (dirCreated) {
            NSData *imageData = UIImagePNGRepresentation(image);
            [imageData writeToFile:filePath atomically:YES];
        }
    }

    if ([info.delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
        [info.delegate imageDownloader:self didDownloadImage:image forURL:info.urlString error:(image ? nil : [NSError errorWithDomain:@"TouchXKCD" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create image"}])];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSValue *key = [NSValue valueWithNonretainedObject:connection];
    ImageRequestInfo *info = [self.downloads objectForKey:key];
    [self.downloads removeObjectForKey:key];
    if (!info) return;
    if ([info.delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
        [info.delegate imageDownloader:self didDownloadImage:nil forURL:info.urlString error:error];
    }
}

@end

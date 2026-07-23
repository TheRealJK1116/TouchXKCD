#import "ImageDownloader.h"
#import "Managers/ImageCache.h"

@interface ImageRequestInfo : NSObject
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSString *urlString;
@property (nonatomic, assign) id<ImageDownloaderDelegate> delegate;
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation ImageRequestInfo
@end

@interface ImageDownloader () <NSURLConnectionDataDelegate, NSURLConnectionDelegate>
@property (nonatomic, strong) NSMutableDictionary *downloads; // key: urlString, value: ImageRequestInfo
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
    if (!filename || filename.length == 0) {
        filename = [NSString stringWithFormat:@"%lu", (unsigned long)[urlString hash]];
    }
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

    // Avoid duplicate downloads for same URL
    @synchronized(self.downloads) {
        ImageRequestInfo *existing = [self.downloads objectForKey:urlString];
        if (existing) {
            // If already downloading, add delegate replacement? For simplicity, overwrite delegate
            existing.delegate = delegate;
            return;
        }
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if ([delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
            [delegate imageDownloader:self didDownloadImage:nil forURL:urlString error:[NSError errorWithDomain:@"TouchXKCD" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL format"}]];
        }
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection) {
        ImageRequestInfo *info = [[ImageRequestInfo alloc] init];
        info.data = [NSMutableData data];
        info.urlString = urlString;
        info.delegate = delegate;
        info.connection = connection;
        @synchronized(self.downloads) {
            [self.downloads setObject:info forKey:urlString];
        }
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [connection start];
    } else {
        if ([delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
            [delegate imageDownloader:self didDownloadImage:nil forURL:urlString error:[NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create connection"}]];
        }
    }
}

- (void)cancelDownloadForURL:(NSString *)urlString {
    if (!urlString) return;
    @synchronized(self.downloads) {
        ImageRequestInfo *info = [self.downloads objectForKey:urlString];
        if (info) {
            [info.connection cancel];
            [self.downloads removeObjectForKey:urlString];
        }
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // Find info by connection
    @synchronized(self.downloads) {
        for (ImageRequestInfo *info in [self.downloads allValues]) {
            if (info.connection == connection) {
                [info.data setLength:0];
                break;
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    @synchronized(self.downloads) {
        for (ImageRequestInfo *info in [self.downloads allValues]) {
            if (info.connection == connection) {
                [info.data appendData:data];
                break;
            }
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    ImageRequestInfo *foundInfo = nil;
    @synchronized(self.downloads) {
        for (NSString *key in [self.downloads allKeys]) {
            ImageRequestInfo *info = [self.downloads objectForKey:key];
            if (info.connection == connection) {
                foundInfo = info;
                [self.downloads removeObjectForKey:key];
                break;
            }
        }
    }
    if (!foundInfo) return;

    UIImage *image = [UIImage imageWithData:foundInfo.data];
    if (image) {
        [[ImageCache sharedCache] cacheImage:image forKey:foundInfo.urlString];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/images"];
        NSString *filename = [foundInfo.urlString lastPathComponent];
        if (!filename || filename.length == 0) filename = [NSString stringWithFormat:@"%lu", (unsigned long)[foundInfo.urlString hash]];
        NSString *filePath = [cacheDir stringByAppendingPathComponent:filename];

        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *writeError = nil;
        if (![fm fileExistsAtPath:cacheDir]) {
            [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:&writeError];
        }
        if (!writeError) {
            // Prefer JPEG for smaller size unless PNG is needed for transparency
            NSData *imageData = nil;
            NSString *ext = [[filename pathExtension] lowercaseString];
            if ([ext isEqualToString:@"png"]) {
                imageData = UIImagePNGRepresentation(image);
            } else {
                imageData = UIImageJPEGRepresentation(image, 0.9);
            }
            [imageData writeToFile:filePath atomically:YES];
        }
    }

    id<ImageDownloaderDelegate> delegate = foundInfo.delegate;
    if ([delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
        [delegate imageDownloader:self didDownloadImage:image forURL:foundInfo.urlString error:(image ? nil : [NSError errorWithDomain:@"TouchXKCD" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create image"}])];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    ImageRequestInfo *foundInfo = nil;
    @synchronized(self.downloads) {
        for (NSString *key in [self.downloads allKeys]) {
            ImageRequestInfo *info = [self.downloads objectForKey:key];
            if (info.connection == connection) {
                foundInfo = info;
                [self.downloads removeObjectForKey:key];
                break;
            }
        }
    }
    if (!foundInfo) return;
    id<ImageDownloaderDelegate> delegate = foundInfo.delegate;
    if ([delegate respondsToSelector:@selector(imageDownloader:didDownloadImage:forURL:error:)]) {
        [delegate imageDownloader:self didDownloadImage:nil forURL:foundInfo.urlString error:error];
    }
}

@end

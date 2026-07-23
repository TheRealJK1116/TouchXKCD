#import "DownloadTask.h"

@interface DownloadTask () <NSURLConnectionDataDelegate, NSURLConnectionDelegate>
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) long long expectedContentLength;
@property (nonatomic, assign) long long downloadedLength;
@end

@implementation DownloadTask

- (id)init {
    self = [super init];
    if (self) {
        self.taskID = 0;
        self.comicNumber = 0;
        self.imageURL = @"";
        self.localPath = @"";
        self.status = DownloadStatusPending;
        self.progress = 0.0f;
        self.createdAt = [NSDate date];
        self.completedAt = nil;
        self.retryCount = 0;
        self.maxRetries = 3;
        self.responseData = [NSMutableData data];
        self.expectedContentLength = 0;
        self.downloadedLength = 0;
    }
    return self;
}

- (NSString *)cachedImagePathForComic:(NSInteger)comicNumber {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/images"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:cacheDir]) {
        [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // Preserve original extension if available from imageURL
    NSString *ext = @"jpg";
    if (self.imageURL) {
        NSString *urlExt = [[self.imageURL lastPathComponent] pathExtension];
        if (urlExt && urlExt.length > 0) ext = urlExt;
    }
    NSString *filename = [NSString stringWithFormat:@"%ld.%@", (long)comicNumber, ext];
    return [cacheDir stringByAppendingPathComponent:filename];
}

- (void)startDownload {
    if (self.status == DownloadStatusCompleted) {
        return;
    }
    // If previously failed and retries exhausted, don't auto-start
    if (self.status == DownloadStatusFailed && self.retryCount >= self.maxRetries) {
        return;
    }
    self.status = DownloadStatusDownloading;
    self.progress = 0.0f;
    self.responseData = [NSMutableData data];
    self.expectedContentLength = 0;
    self.downloadedLength = 0;

    if (!self.imageURL || self.imageURL.length == 0) {
        self.imageURL = [NSString stringWithFormat:@"https://imgs.xkcd.com/comics/%ld.png", (long)self.comicNumber];
    }
    NSURL *url = [NSURL URLWithString:self.imageURL];
    if (!url) {
        NSLog(@"[DownloadTask] Invalid URL %@ for comic %ld", self.imageURL, (long)self.comicNumber);
        [self handleFailure];
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (self.connection) {
        [self.connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.connection start];
    } else {
        [self handleFailure];
    }
}

- (void)handleFailure {
    self.retryCount += 1;
    if (self.retryCount < self.maxRetries) {
        self.status = DownloadStatusPending;
        self.progress = 0.0f;
        // Exponential backoff: 2, 4, 8 seconds
        NSTimeInterval delay = 2.0 * (1 << (self.retryCount - 1));
        if (delay > 30) delay = 30;
        [self performSelector:@selector(startDownload) withObject:nil afterDelay:delay];
        return;
    }
    self.status = DownloadStatusFailed;
    self.connection = nil;
    if ([self.delegate respondsToSelector:@selector(downloadTaskDidFail:)]) {
        [self.delegate downloadTaskDidFail:self];
    }
}

- (void)cancel {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startDownload) object:nil];
    [self.connection cancel];
    self.connection = nil;
    // Only mark as failed if not already completed
    if (self.status != DownloadStatusCompleted) {
        self.status = DownloadStatusFailed;
        if ([self.delegate respondsToSelector:@selector(downloadTaskDidFail:)]) {
            [self.delegate downloadTaskDidFail:self];
        }
    }
}

- (BOOL)isActive {
    return (self.status == DownloadStatusPending || self.status == DownloadStatusDownloading);
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.responseData setLength:0];
    self.expectedContentLength = [response expectedContentLength];
    self.downloadedLength = 0;
    if (self.expectedContentLength <= 0) {
        // If server doesn't provide length, assume 1 to avoid div0, progress will be indeterminate but we estimate
        self.expectedContentLength = 1024 * 1024; // 1MB guess
    }
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        if (code >= 400) {
            NSLog(@"[DownloadTask] HTTP %ld for comic %ld URL %@", (long)code, (long)self.comicNumber, self.imageURL);
            if (code == 404) {
                // Don't retry 404
                self.retryCount = self.maxRetries;
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    self.downloadedLength += [data length];
    float progress = (float)self.downloadedLength / (float)self.expectedContentLength;
    if (progress > 1.0f) progress = 1.0f;
    if (progress < 0) progress = 0;
    self.progress = progress;
    if ([self.delegate respondsToSelector:@selector(downloadTask:didUpdateProgress:)]) {
        [self.delegate downloadTask:self didUpdateProgress:self.progress];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.connection = nil;
    self.status = DownloadStatusCompleted;
    self.progress = 1.0f;
    self.completedAt = [NSDate date];
    NSString *localPath = [self cachedImagePathForComic:self.comicNumber];
    // If server gave us data but we overwrote path extension, ensure dir exists
    NSString *dir = [localPath stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    BOOL wrote = [self.responseData writeToFile:localPath atomically:YES];
    if (!wrote) {
        NSLog(@"[DownloadTask] Failed to write file to %@", localPath);
        [self handleFailure];
        return;
    }
    self.localPath = localPath;
    // Clear response data to save memory
    self.responseData = nil;
    if ([self.delegate respondsToSelector:@selector(downloadTaskDidComplete:)]) {
        [self.delegate downloadTaskDidComplete:self];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"[DownloadTask] Failed for comic %ld: %@", (long)self.comicNumber, error);
    self.connection = nil;
    [self handleFailure];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.taskID forKey:@"taskID"];
    [coder encodeInteger:self.comicNumber forKey:@"comicNumber"];
    [coder encodeObject:self.imageURL forKey:@"imageURL"];
    [coder encodeObject:self.localPath forKey:@"localPath"];
    [coder encodeInteger:self.status forKey:@"status"];
    [coder encodeFloat:self.progress forKey:@"progress"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
    [coder encodeObject:self.completedAt forKey:@"completedAt"];
    [coder encodeInteger:self.retryCount forKey:@"retryCount"];
    [coder encodeInteger:self.maxRetries forKey:@"maxRetries"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.taskID = [coder decodeIntegerForKey:@"taskID"];
        self.comicNumber = [coder decodeIntegerForKey:@"comicNumber"];
        self.imageURL = [coder decodeObjectForKey:@"imageURL"];
        self.localPath = [coder decodeObjectForKey:@"localPath"];
        self.status = [coder decodeIntegerForKey:@"status"];
        self.progress = [coder decodeFloatForKey:@"progress"];
        self.createdAt = [coder decodeObjectForKey:@"createdAt"];
        self.completedAt = [coder decodeObjectForKey:@"completedAt"];
        self.retryCount = [coder decodeIntegerForKey:@"retryCount"];
        self.maxRetries = [coder decodeIntegerForKey:@"maxRetries"];
        if (self.createdAt == nil) self.createdAt = [NSDate date];
        if (self.maxRetries == 0) self.maxRetries = 3;
        self.responseData = [NSMutableData data];
        self.expectedContentLength = 0;
        self.downloadedLength = 0;
        // If completed but file missing, reset to pending
        if (self.status == DownloadStatusCompleted && self.localPath) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:self.localPath]) {
                self.status = DownloadStatusPending;
                self.progress = 0;
            }
        }
    }
    return self;
}

@end

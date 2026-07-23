#import "DownloadTask.h"

@interface DownloadTask ()
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
    NSString *filename = [NSString stringWithFormat:@"%ld.jpg", (long)comicNumber];
    return [cacheDir stringByAppendingPathComponent:filename];
}

- (void)startDownload {
    if (self.status == DownloadStatusCompleted || self.status == DownloadStatusFailed) {
        return;
    }
    self.status = DownloadStatusDownloading;
    self.progress = 0.0f;
    self.responseData = [NSMutableData data];
    self.expectedContentLength = 0;
    self.downloadedLength = 0;

    if (!self.imageURL || self.imageURL.length == 0) {
        self.imageURL = [NSString stringWithFormat:@"https://imgs.xkcd.com/comics/%ld.jpg", (long)self.comicNumber];
    }
    NSURL *url = [NSURL URLWithString:self.imageURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (self.connection) {
        [self.connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.connection start];
    }
}

- (void)cancel {
    [self.connection cancel];
    self.connection = nil;
    self.status = DownloadStatusFailed;
    if ([self.delegate respondsToSelector:@selector(downloadTaskDidFail:)]) {
        [self.delegate downloadTaskDidFail:self];
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
        self.expectedContentLength = 1;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    self.downloadedLength += [data length];
    float progress = (float)self.downloadedLength / (float)self.expectedContentLength;
    if (progress > 1.0f) progress = 1.0f;
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
    [self.responseData writeToFile:localPath atomically:YES];
    self.localPath = localPath;
    if ([self.delegate respondsToSelector:@selector(downloadTaskDidComplete:)]) {
        [self.delegate downloadTaskDidComplete:self];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.connection = nil;
    self.retryCount += 1;
    if (self.retryCount < self.maxRetries) {
        self.status = DownloadStatusPending;
        self.progress = 0.0f;
        [self performSelector:@selector(startDownload) withObject:nil afterDelay:2.0];
        return;
    }
    self.status = DownloadStatusFailed;
    if ([self.delegate respondsToSelector:@selector(downloadTaskDidFail:)]) {
        [self.delegate downloadTaskDidFail:self];
    }
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
    }
    return self;
}

@end

#import "DownloadManager.h"
#import "DownloadTask.h"

@interface DownloadManager ()
@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSMutableArray *completedTasks;
@property (nonatomic, strong) NSMutableArray *failedTasks;
@property (nonatomic, assign) BOOL isProcessing;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;
@end

@implementation DownloadManager

+ (instancetype)sharedManager {
    static DownloadManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.queue = [NSMutableArray array];
        shared.completedTasks = [NSMutableArray array];
        shared.failedTasks = [NSMutableArray array];
        shared.isProcessing = NO;
        shared.backgroundTask = UIBackgroundTaskInvalid;
        [shared loadQueue];
    });
    return shared;
}

- (NSString *)queueFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/downloads"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [dir stringByAppendingPathComponent:@"queue.archive"];
}

- (void)saveQueue {
    NSArray *allTasks = [[_queue arrayByAddingObjectsFromArray:self.completedTasks] arrayByAddingObjectsFromArray:self.failedTasks];
    [NSKeyedArchiver archiveRootObject:allTasks toFile:[self queueFilePath]];
}

- (void)loadQueue {
    NSArray *loaded = [NSKeyedUnarchiver unarchiveObjectWithFile:[self queueFilePath]];
    if (loaded) {
        [_queue removeAllObjects];
        [_completedTasks removeAllObjects];
        [_failedTasks removeAllObjects];
        for (DownloadTask *task in loaded) {
            if (task.status == DownloadStatusCompleted) {
                [_completedTasks addObject:task];
            } else if (task.status == DownloadStatusFailed) {
                [_failedTasks addObject:task];
            } else {
                [_queue addObject:task];
            }
        }
    }
}

- (void)resumeQueuedDownloads {
    if (self.isProcessing) return;
    [self processNextTask];
}

- (void)processNextTask {
    if (self.isProcessing) return;
    if ([_queue count] == 0) {
        self.isProcessing = NO;
        if (self.backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
        return;
    }
    self.isProcessing = YES;
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self cancelAllActiveConnections];
    }];
    DownloadTask *task = [_queue objectAtIndex:0];
    if (task.status == DownloadStatusFailed && task.retryCount < task.maxRetries) {
        task.status = DownloadStatusPending;
        task.retryCount = 0;
    }
    [_queue removeObjectAtIndex:0];
    [self saveQueue];
    task.delegate = self;
    [task startDownload];
}

- (void)cancelAllActiveConnections {
    for (DownloadTask *task in [_queue copy]) {
        [task cancel];
    }
    for (DownloadTask *task in [_completedTasks copy]) {
        [task cancel];
    }
    for (DownloadTask *task in [_failedTasks copy]) {
        [task cancel];
    }
}

- (void)addTask:(DownloadTask *)task {
    task.taskID = [_queue count] + [_completedTasks count] + 1;
    task.createdAt = [NSDate date];
    task.status = DownloadStatusPending;
    [_queue addObject:task];
    [self saveQueue];
    [self resumeQueuedDownloads];
}

- (void)cancelTask:(DownloadTask *)task {
    [task cancel];
    [_queue removeObject:task];
    [_completedTasks removeObject:task];
    [_failedTasks addObject:task];
    [self saveQueue];
}

- (void)removeTask:(DownloadTask *)task {
    [_queue removeObject:task];
    [_completedTasks removeObject:task];
    [_failedTasks removeObject:task];
    [self saveQueue];
}

- (NSArray *)allTasks {
    NSMutableArray *all = [NSMutableArray array];
    [all addObjectsFromArray:_queue];
    [all addObjectsFromArray:_completedTasks];
    [all addObjectsFromArray:_failedTasks];
    return all;
}

- (NSArray *)activeTasks {
    NSMutableArray *active = [NSMutableArray array];
    for (DownloadTask *task in self.queue) {
        if ([task isActive]) {
            [active addObject:task];
        }
    }
    return active;
}

- (NSArray *)completedTasks {
    return [self->_completedTasks copy];
}

- (NSArray *)failedTasks {
    return [self->_failedTasks copy];
}

- (void)downloadComic:(NSInteger)comicNumber delegate:(id<DownloadDelegateProtocol>)delegate {
    DownloadTask *task = [[DownloadTask alloc] init];
    task.comicNumber = comicNumber;
    task.imageURL = [NSString stringWithFormat:@"https://imgs.xkcd.com/comics/%ld.jpg", (long)comicNumber];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/images"];
    NSString *filename = [NSString stringWithFormat:@"%ld.jpg", (long)comicNumber];
    NSString *localPath = [cacheDir stringByAppendingPathComponent:filename];
    task.localPath = localPath;
    task.delegate = delegate ? delegate : self;
    [self addTask:task];
}

- (void)downloadComicRangeFrom:(NSInteger)start to:(NSInteger)end delegate:(id<DownloadDelegateProtocol>)delegate {
    for (NSInteger i = start; i <= end; i++) {
        [self downloadComic:i delegate:delegate];
    }
}

- (void)downloadFullArchive:(NSInteger)maxComicNumber delegate:(id<DownloadDelegateProtocol>)delegate {
    [self downloadComicRangeFrom:1 to:maxComicNumber delegate:delegate];
}

- (NSString *)imageCachePathForComic:(NSInteger)comicNumber {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/images"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:cacheDir]) {
        [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.jpg", (long)comicNumber]];
}

- (NSInteger)queueCount {
    return [_queue count] + [self.activeTasks count];
}

- (NSInteger)completedCount {
    return [_completedTasks count];
}

#pragma mark - DownloadDelegateProtocol

- (void)downloadTask:(DownloadTask *)task didUpdateProgress:(float)progress {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDDownloadProgressUpdated" object:task];
    [self saveQueue];
}

- (void)downloadTaskDidComplete:(DownloadTask *)task {
    [_queue removeObject:task];
    [_completedTasks addObject:task];
    [self saveQueue];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDDownloadCompleted" object:task];
    [self processNextTask];
}

- (void)downloadTaskDidFail:(DownloadTask *)task {
    [_queue removeObject:task];
    [_failedTasks addObject:task];
    [self saveQueue];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDDownloadFailed" object:task];
    [self processNextTask];
}

- (void)pauseAllDownloads {
    for (DownloadTask *task in [self.activeTasks copy]) {
        [task cancel];
    }
    [self saveQueue];
}

- (void)dealloc {
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

@end

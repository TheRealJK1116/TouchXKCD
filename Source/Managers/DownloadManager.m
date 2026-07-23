#import "DownloadManager.h"
#import "DownloadTask.h"
#import "Models/Comic.h"
#import "Managers/StorageManager.h"

@interface DownloadManager ()
@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSMutableArray *internalCompletedTasks;
@property (nonatomic, strong) NSMutableArray *internalFailedTasks;
@property (nonatomic, strong) DownloadTask *currentTask;
@property (nonatomic, assign) BOOL isProcessing;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;
@end

@implementation DownloadManager

@synthesize queue = _queue;
@synthesize internalCompletedTasks = _internalCompletedTasks;
@synthesize internalFailedTasks = _internalFailedTasks;
@synthesize currentTask = _currentTask;
@synthesize isProcessing = _isProcessing;
@synthesize backgroundTask = _backgroundTask;

+ (instancetype)sharedManager {
    static DownloadManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.queue = [NSMutableArray array];
        shared.internalCompletedTasks = [NSMutableArray array];
        shared.internalFailedTasks = [NSMutableArray array];
        shared.isProcessing = NO;
        shared.backgroundTask = UIBackgroundTaskInvalid;
        shared.currentTask = nil;
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
    NSMutableArray *all = [NSMutableArray array];
    @synchronized(self) {
        if (_currentTask) {
            [all addObject:_currentTask];
        }
        [all addObjectsFromArray:_queue];
        [all addObjectsFromArray:_internalCompletedTasks];
        [all addObjectsFromArray:_internalFailedTasks];
    }
    @try {
        [NSKeyedArchiver archiveRootObject:all toFile:[self queueFilePath]];
    } @catch (NSException *ex) {
        NSLog(@"[DownloadManager] Failed to archive queue: %@", ex);
    }
}

- (void)loadQueue {
    NSArray *loaded = nil;
    @try {
        loaded = [NSKeyedUnarchiver unarchiveObjectWithFile:[self queueFilePath]];
    } @catch (NSException *ex) {
        NSLog(@"[DownloadManager] Failed to unarchive queue: %@", ex);
        loaded = nil;
    }
    if (loaded) {
        @synchronized(self) {
            [_queue removeAllObjects];
            [_internalCompletedTasks removeAllObjects];
            [_internalFailedTasks removeAllObjects];
            _currentTask = nil;
            for (DownloadTask *task in loaded) {
                if (![task isKindOfClass:[DownloadTask class]]) continue;
                if (task.status == DownloadStatusCompleted) {
                    [_internalCompletedTasks addObject:task];
                } else if (task.status == DownloadStatusFailed) {
                    [_internalFailedTasks addObject:task];
                } else {
                    if (task.status == DownloadStatusDownloading) {
                        task.status = DownloadStatusPending;
                        task.progress = 0.0f;
                    }
                    [_queue addObject:task];
                }
            }
        }
    }
}

- (void)resumeQueuedDownloads {
    [self processNextTask];
}

- (void)processNextTask {
    @synchronized(self) {
        if (_isProcessing) {
            return;
        }
        if (_currentTask && _currentTask.status == DownloadStatusDownloading) {
            return;
        }
        if ([_queue count] == 0) {
            _isProcessing = NO;
            _currentTask = nil;
            if (_backgroundTask != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
                _backgroundTask = UIBackgroundTaskInvalid;
            }
            return;
        }
        _isProcessing = YES;
    }

    if (_backgroundTask == UIBackgroundTaskInvalid) {
        _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self pauseAllDownloads];
            @synchronized(self) {
                _isProcessing = NO;
            }
            if (_backgroundTask != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
                _backgroundTask = UIBackgroundTaskInvalid;
            }
        }];
    }

    DownloadTask *nextTask = nil;
    @synchronized(self) {
        if ([_queue count] > 0) {
            nextTask = [_queue objectAtIndex:0];
            [_queue removeObjectAtIndex:0];
            if (nextTask.status == DownloadStatusFailed && nextTask.retryCount < nextTask.maxRetries) {
                nextTask.status = DownloadStatusPending;
                nextTask.retryCount = 0;
            }
            _currentTask = nextTask;
        }
    }

    if (nextTask) {
        [self saveQueue];
        nextTask.delegate = self;
        [nextTask startDownload];
    } else {
        @synchronized(self) {
            _isProcessing = NO;
            _currentTask = nil;
        }
    }
}

- (void)cancelAllActiveConnections {
    DownloadTask *taskToCancel = nil;
    @synchronized(self) {
        taskToCancel = _currentTask;
    }
    if (taskToCancel) {
        [taskToCancel cancel];
    }
    @synchronized(self) {
        for (DownloadTask *task in [_queue copy]) {
            [task cancel];
        }
    }
}

- (void)addTask:(DownloadTask *)task {
    if (!task) return;
    @synchronized(self) {
        for (DownloadTask *existing in _queue) {
            if (existing.comicNumber == task.comicNumber) {
                return;
            }
        }
        for (DownloadTask *existing in _internalCompletedTasks) {
            if (existing.comicNumber == task.comicNumber) {
                return;
            }
        }
        NSMutableArray *toRemove = [NSMutableArray array];
        for (DownloadTask *existing in _internalFailedTasks) {
            if (existing.comicNumber == task.comicNumber) {
                [toRemove addObject:existing];
            }
        }
        [_internalFailedTasks removeObjectsInArray:toRemove];

        task.taskID = [_queue count] + [_internalCompletedTasks count] + [_internalFailedTasks count] + 1;
        task.createdAt = [NSDate date];
        task.status = DownloadStatusPending;
        [_queue addObject:task];
    }
    [self saveQueue];
    [self resumeQueuedDownloads];
}

- (void)cancelTask:(DownloadTask *)task {
    if (!task) return;
    BOOL wasCurrent = NO;
    @synchronized(self) {
        wasCurrent = (_currentTask == task);
    }
    [task cancel];

    @synchronized(self) {
        if (wasCurrent) {
            _currentTask = nil;
            _isProcessing = NO;
        }
        [_queue removeObject:task];
        if (![_internalFailedTasks containsObject:task]) {
            if (task.status != DownloadStatusCompleted) {
                task.status = DownloadStatusFailed;
                [_internalFailedTasks addObject:task];
            }
        }
    }
    [self saveQueue];
    if (wasCurrent) {
        [self processNextTask];
    }
}

- (void)removeTask:(DownloadTask *)task {
    if (!task) return;
    BOOL wasCurrent = NO;
    @synchronized(self) {
        wasCurrent = (_currentTask == task);
        [_queue removeObject:task];
        [_internalCompletedTasks removeObject:task];
        [_internalFailedTasks removeObject:task];
        if (wasCurrent) {
            _currentTask = nil;
            _isProcessing = NO;
        }
    }
    [self saveQueue];
    if (wasCurrent) {
        [self processNextTask];
    }
}

- (NSArray *)allTasks {
    NSMutableArray *all = [NSMutableArray array];
    @synchronized(self) {
        if (_currentTask) [all addObject:_currentTask];
        [all addObjectsFromArray:_queue];
        [all addObjectsFromArray:_internalCompletedTasks];
        [all addObjectsFromArray:_internalFailedTasks];
    }
    return [all copy];
}

- (NSArray *)activeTasks {
    NSMutableArray *active = [NSMutableArray array];
    @synchronized(self) {
        if (_currentTask && [_currentTask isActive]) {
            [active addObject:_currentTask];
        }
        for (DownloadTask *task in _queue) {
            if ([task isActive]) {
                [active addObject:task];
            }
        }
    }
    return [active copy];
}

- (NSArray *)completedTasks {
    @synchronized(self) {
        return [_internalCompletedTasks copy];
    }
}

- (NSArray *)failedTasks {
    @synchronized(self) {
        return [_internalFailedTasks copy];
    }
}

- (void)downloadComic:(NSInteger)comicNumber delegate:(id<DownloadDelegateProtocol>)delegate {
    if (comicNumber <= 0) return;
    Comic *cached = [[StorageManager sharedManager] loadComic:comicNumber];
    NSString *imageURL = nil;
    if (cached && cached.imageURL && cached.imageURL.length > 0) {
        imageURL = cached.imageURL;
    } else {
        imageURL = [NSString stringWithFormat:@"https://imgs.xkcd.com/comics/%ld.png", (long)comicNumber];
    }
    DownloadTask *task = [[DownloadTask alloc] init];
    task.comicNumber = comicNumber;
    task.imageURL = imageURL;
    task.localPath = [self imageCachePathForComic:comicNumber];
    task.delegate = delegate ? delegate : self;
    [self addTask:task];
}

- (void)downloadComicRangeFrom:(NSInteger)start to:(NSInteger)end delegate:(id<DownloadDelegateProtocol>)delegate {
    if (start <= 0) start = 1;
    if (end < start) return;
    for (NSInteger i = start; i <= end; i++) {
        [self downloadComic:i delegate:delegate];
    }
}

- (void)downloadFullArchive:(NSInteger)maxComicNumber delegate:(id<DownloadDelegateProtocol>)delegate {
    if (maxComicNumber <= 0) maxComicNumber = 2500;
    [self downloadComicRangeFrom:1 to:maxComicNumber delegate:delegate];
}

- (NSString *)imageCachePathForComic:(NSInteger)comicNumber {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/images"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:cacheDir]) {
        [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *ext = @"jpg";
    Comic *cached = [[StorageManager sharedManager] loadComic:comicNumber];
    if (cached && cached.imageURL) {
        NSString *lastComp = [cached.imageURL lastPathComponent];
        NSString *fileExt = [lastComp pathExtension];
        if (fileExt && fileExt.length > 0) {
            ext = fileExt;
        }
    }
    return [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.%@", (long)comicNumber, ext]];
}

- (NSInteger)queueCount {
    @synchronized(self) {
        NSInteger count = [_queue count];
        if (_currentTask && [_currentTask isActive]) count += 1;
        return count;
    }
}

- (NSInteger)completedCount {
    @synchronized(self) {
        return [_internalCompletedTasks count];
    }
}

#pragma mark - DownloadDelegateProtocol

- (void)downloadTask:(DownloadTask *)task didUpdateProgress:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDDownloadProgressUpdated" object:task];
    });
    [self saveQueue];
}

- (void)downloadTaskDidComplete:(DownloadTask *)task {
    @synchronized(self) {
        if (_currentTask == task) {
            _currentTask = nil;
        }
        [_queue removeObject:task];
        if (![_internalCompletedTasks containsObject:task]) {
            [_internalCompletedTasks addObject:task];
        }
        _isProcessing = NO;
    }
    [self saveQueue];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDDownloadCompleted" object:task];
    });
    [self processNextTask];
}

- (void)downloadTaskDidFail:(DownloadTask *)task {
    @synchronized(self) {
        if (_currentTask == task) {
            _currentTask = nil;
        }
        [_queue removeObject:task];
        if (![_internalFailedTasks containsObject:task] && ![_internalCompletedTasks containsObject:task]) {
            [_internalFailedTasks addObject:task];
        }
        _isProcessing = NO;
    }
    [self saveQueue];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDDownloadFailed" object:task];
    });
    [self processNextTask];
}

- (void)pauseAllDownloads {
    DownloadTask *current = nil;
    @synchronized(self) {
        current = _currentTask;
    }
    if (current) {
        [current cancel];
    }
    @synchronized(self) {
        _isProcessing = NO;
        _currentTask = nil;
    }
    [self saveQueue];
}

- (void)dealloc {
    if (_backgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }
}

@end

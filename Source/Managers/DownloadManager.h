#import <Foundation/Foundation.h>
#import "Protocols/DownloadDelegateProtocol.h"

@class DownloadTask;

@interface DownloadManager : NSObject <DownloadDelegateProtocol>

+ (instancetype)sharedManager;

- (void)addTask:(DownloadTask *)task;
- (void)cancelTask:(DownloadTask *)task;
- (void)removeTask:(DownloadTask *)task;

- (NSArray *)allTasks;
- (NSArray *)activeTasks;
- (NSArray *)completedTasks;
- (NSArray *)failedTasks;

- (void)downloadComic:(NSInteger)comicNumber delegate:(id<DownloadDelegateProtocol>)delegate;
- (void)downloadComicRangeFrom:(NSInteger)start to:(NSInteger)end delegate:(id<DownloadDelegateProtocol>)delegate;
- (void)downloadFullArchive:(NSInteger)maxComicNumber delegate:(id<DownloadDelegateProtocol>)delegate;

- (void)saveQueue;
- (void)loadQueue;
- (void)resumeQueuedDownloads;
- (void)pauseAllDownloads;

- (NSInteger)queueCount;
- (NSInteger)completedCount;

@end

#import <Foundation/Foundation.h>

@class DownloadTask;

@protocol DownloadDelegateProtocol <NSObject>
- (void)downloadTask:(DownloadTask *)task didUpdateProgress:(float)progress;
- (void)downloadTaskDidComplete:(DownloadTask *)task;
- (void)downloadTaskDidFail:(DownloadTask *)task;
@end

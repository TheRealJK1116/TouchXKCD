#import <Foundation/Foundation.h>
#import "Protocols/DownloadDelegateProtocol.h"

typedef NS_ENUM(NSInteger, DownloadStatus) {
    DownloadStatusPending = 0,
    DownloadStatusDownloading,
    DownloadStatusCompleted,
    DownloadStatusFailed
};

@interface DownloadTask : NSObject <NSCoding, NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, assign) NSInteger taskID;
@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, strong) NSString *imageURL;
@property (nonatomic, strong) NSString *localPath;
@property (nonatomic, assign) DownloadStatus status;
@property (nonatomic, assign) float progress;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *completedAt;
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, assign) NSInteger maxRetries;
@property (nonatomic, assign) id<DownloadDelegateProtocol> delegate;

- (void)startDownload;
- (void)cancel;
- (BOOL)isActive;

@end

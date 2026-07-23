#import <Foundation/Foundation.h>

@class UIImage;

@protocol ImageDownloaderDelegate <NSObject>
- (void)imageDownloader:(id)downloader didDownloadImage:(UIImage *)image forURL:(NSString *)urlString error:(NSError *)error;
@end

@interface ImageDownloader : NSObject

+ (instancetype)sharedDownloader;
- (void)downloadImageFromURL:(NSString *)urlString delegate:(id<ImageDownloaderDelegate>)delegate;
- (void)cancelDownloadForURL:(NSString *)urlString;

@end

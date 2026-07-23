#import <UIKit/UIKit.h>
#import "Protocols/ComicNetworkProtocol.h"
#import "Managers/ImageDownloader.h"

@interface ComicDetailViewController : UIViewController <ComicNetworkDelegate, ImageDownloaderDelegate>

@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, strong) UIImageView *comicImageView;
@property (nonatomic, strong) UITextView *explanationTextView;

@end

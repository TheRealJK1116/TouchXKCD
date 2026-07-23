#import <UIKit/UIKit.h>
#import "Protocols/ComicNetworkProtocol.h"
#import "Protocols/DownloadDelegateProtocol.h"
#import "Managers/ImageDownloader.h"
#import "Managers/ExplanationProvider.h"

@class Comic;

@interface ComicsViewController : UIViewController <ComicNetworkDelegate, DownloadDelegateProtocol, ImageDownloaderDelegate, UIAlertViewDelegate, ExplanationProviderDelegate>

@property (nonatomic, strong) Comic *currentComic;
@property (nonatomic, strong) UIImageView *comicImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UITextView *altTextView;
@property (nonatomic, strong) UITextView *transcriptTextView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *randomButton;
@property (nonatomic, strong) UIButton *jumpButton;

- (void)loadComic:(NSInteger)number;
- (void)showLatestComic;
- (void)showRandomComic;
- (void)showPreviousComic;
- (void)showNextComic;

@end

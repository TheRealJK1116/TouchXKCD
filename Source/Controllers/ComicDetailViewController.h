#import <UIKit/UIKit.h>

@interface ComicDetailViewController : UIViewController

@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, strong) UIImageView *comicImageView;
@property (nonatomic, strong) UITextView *explanationTextView;

@end

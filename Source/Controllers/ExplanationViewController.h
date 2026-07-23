#import <UIKit/UIKit.h>

@interface ExplanationViewController : UIViewController

@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, strong) UITextView *explanationView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *loadButton;

@end

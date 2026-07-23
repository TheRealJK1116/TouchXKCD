#import "ComicDetailViewController.h"

@implementation ComicDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"Comic #%ld", (long)self.comicNumber];
    self.view.backgroundColor = [UIColor whiteColor];

    self.comicImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 300, 300)];
    self.comicImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.comicImageView];

    self.explanationTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 320, 300, 200)];
    self.explanationTextView.editable = NO;
    self.explanationTextView.font = [UIFont systemFontOfSize:14.0f];
    [self.view addSubview:self.explanationTextView];
}

@end

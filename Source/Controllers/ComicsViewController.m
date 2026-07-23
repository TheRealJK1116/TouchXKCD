#import "ComicsViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "Models/Comic.h"
#import "Controllers/ComicDetailViewController.h"
#import "Managers/ComicManager.h"
#import "Managers/ImageCache.h"
#import "Managers/ImageDownloader.h"
#import "Managers/DownloadManager.h"
#import "Controllers/ExplanationViewController.h"
#import "Managers/DownloadTask.h"
#import "Models/Favourite.h"
#import "Managers/SettingsManager.h"
#import "Managers/StorageManager.h"

@interface ComicsViewController () <DownloadDelegateProtocol>
@property (nonatomic, assign) NSInteger currentComicNumber;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *favButton;
@property (nonatomic, strong) UIButton *downloadButton;
@property (nonatomic, strong) UILabel *altHeaderLabel;
@property (nonatomic, strong) UILabel *transcriptHeaderLabel;
@end

@implementation ComicsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Comics";
    self.view.backgroundColor = [UIColor colorWithRed:0.937f green:0.937f blue:0.957f alpha:1.0f];
    self.currentComicNumber = 1;

    UIBarButtonItem *latestItem = [[UIBarButtonItem alloc] initWithTitle:@"Latest" style:UIBarButtonItemStyleDone target:self action:@selector(showLatestComic)];
    UIBarButtonItem *explainItem = [[UIBarButtonItem alloc] initWithTitle:@"Explain" style:UIBarButtonItemStyleBordered target:self action:@selector(showExplanation)];
    self.navigationItem.rightBarButtonItems = @[latestItem, explainItem];

    CGFloat viewWidth = 320.0f;
    CGFloat bottomBarHeight = 50.0f;
    CGFloat scrollHeight = 320.0f;
    if (self.view.bounds.size.height > 0) {
        CGFloat availableHeight = self.view.bounds.size.height;
        if (availableHeight > 400) {
            availableHeight = availableHeight - 44 - 49;
            if (availableHeight > bottomBarHeight) {
                scrollHeight = availableHeight - bottomBarHeight - 5;
            }
        }
    }

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, scrollHeight)];
    self.scrollView.contentSize = CGSizeMake(viewWidth, 600);
    self.scrollView.showsVerticalScrollIndicator = YES;
    self.scrollView.backgroundColor = [UIColor whiteColor];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 300, 30)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.titleLabel];

    self.comicImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 45, 300, 200)];
    self.comicImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.comicImageView.backgroundColor = [UIColor whiteColor];
    self.comicImageView.layer.borderColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0].CGColor;
    self.comicImageView.layer.borderWidth = 1.0f;
    self.comicImageView.layer.cornerRadius = 4.0f;
    self.comicImageView.clipsToBounds = YES;
    [self.scrollView addSubview:self.comicImageView];

    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 250, 300, 20)];
    self.dateLabel.font = [UIFont systemFontOfSize:12.0f];
    self.dateLabel.textColor = [UIColor darkGrayColor];
    self.dateLabel.textAlignment = NSTextAlignmentCenter;
    self.dateLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.dateLabel];

    // Alt text header - section label
    self.altHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 275, 300, 18)];
    self.altHeaderLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    self.altHeaderLabel.textColor = [UIColor darkGrayColor];
    self.altHeaderLabel.text = @"Alt Text:";
    self.altHeaderLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.altHeaderLabel];

    // Alt text view - flexible box
    self.altTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 295, 300, 70)];
    self.altTextView.font = [UIFont systemFontOfSize:13.0f];
    self.altTextView.editable = NO;
    self.altTextView.scrollEnabled = NO; // Flexible, no inner scroll initially
    self.altTextView.textColor = [UIColor darkGrayColor];
    self.altTextView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0];
    self.altTextView.layer.cornerRadius = 6.0f;
    self.altTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.altTextView.layer.borderWidth = 0.5f;
    self.altTextView.contentInset = UIEdgeInsetsMake(6, 6, 6, 6);
    [self.scrollView addSubview:self.altTextView];

    // Transcript header - section under alt text
    self.transcriptHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 375, 300, 18)];
    self.transcriptHeaderLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    self.transcriptHeaderLabel.textColor = [UIColor darkGrayColor];
    self.transcriptHeaderLabel.text = @"Transcript:";
    self.transcriptHeaderLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.transcriptHeaderLabel];

    // Transcript text view - flexible box
    self.transcriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 395, 300, 70)];
    self.transcriptTextView.font = [UIFont systemFontOfSize:12.0f];
    self.transcriptTextView.editable = NO;
    self.transcriptTextView.scrollEnabled = NO; // Flexible
    self.transcriptTextView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0];
    self.transcriptTextView.layer.cornerRadius = 6.0f;
    self.transcriptTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.transcriptTextView.layer.borderWidth = 0.5f;
    self.transcriptTextView.contentInset = UIEdgeInsetsMake(6, 6, 6, 6);
    [self.scrollView addSubview:self.transcriptTextView];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.activityIndicator setCenter:CGPointMake(160, 140)];
    self.activityIndicator.hidesWhenStopped = YES;
    [self.activityIndicator startAnimating];
    [self.scrollView addSubview:self.activityIndicator];

    self.downloadButton = [self createButton:@"Download" frame:CGRectMake(230, 5, 70, 30) action:@selector(startDownloadCurrentComic)];
    [self.scrollView addSubview:self.downloadButton];

    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, scrollHeight + 2, viewWidth, bottomBarHeight)];
    self.bottomBar.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    self.bottomBar.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.bottomBar.layer.borderWidth = 0.5f;
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.bottomBar];

    CGFloat buttonWidth = 58;
    CGFloat spacing = 4;
    CGFloat totalWidth = buttonWidth * 5 + spacing * 4;
    CGFloat startX = (viewWidth - totalWidth) / 2;
    CGFloat buttonY = 7;
    CGFloat buttonHeight = 36;

    self.prevButton = [self createButton:@"Prev" frame:CGRectMake(startX, buttonY, buttonWidth, buttonHeight) action:@selector(showPreviousComic)];
    self.nextButton = [self createButton:@"Next" frame:CGRectMake(startX + (buttonWidth + spacing), buttonY, buttonWidth, buttonHeight) action:@selector(showNextComic)];
    self.randomButton = [self createButton:@"Random" frame:CGRectMake(startX + (buttonWidth + spacing) * 2, buttonY, buttonWidth, buttonHeight) action:@selector(showRandomComic)];
    self.favButton = [self createButton:@"Fav" frame:CGRectMake(startX + (buttonWidth + spacing) * 3, buttonY, buttonWidth, buttonHeight) action:@selector(toggleFavouriteCurrentComic)];
    self.jumpButton = [self createButton:@"Jump" frame:CGRectMake(startX + (buttonWidth + spacing) * 4, buttonY, buttonWidth, buttonHeight) action:@selector(showJump)];

    [self.bottomBar addSubview:self.prevButton];
    [self.bottomBar addSubview:self.nextButton];
    [self.bottomBar addSubview:self.randomButton];
    [self.bottomBar addSubview:self.favButton];
    [self.bottomBar addSubview:self.jumpButton];

    [self applySettings];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applySettings) name:@"TouchXKCDSettingsChanged" object:nil];
    [self showLatestComic];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applySettings];
    [self.view bringSubviewToFront:self.bottomBar];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat viewWidth = self.view.bounds.size.width;
    CGFloat viewHeight = self.view.bounds.size.height;
    CGFloat bottomBarHeight = 50.0f;
    self.bottomBar.frame = CGRectMake(0, viewHeight - bottomBarHeight, viewWidth, bottomBarHeight);
    self.scrollView.frame = CGRectMake(0, 0, viewWidth, viewHeight - bottomBarHeight - 2);
}

- (void)applySettings {
    Settings *settings = [[SettingsManager sharedInstance] currentSettings];
    self.altTextView.hidden = !settings.showAltText;
    self.altHeaderLabel.hidden = !settings.showAltText;
    [self layoutFlexibleBoxes];
}

- (void)layoutFlexibleBoxes {
    // Flexible boxes: adjust height based on content, with min/max
    CGFloat maxBoxHeight = 140.0f;
    CGFloat minBoxHeight = 50.0f;
    CGFloat width = 300.0f;

    // Alt text flexible height
    CGFloat altHeight = minBoxHeight;
    if (self.altTextView.text && self.altTextView.text.length > 0) {
        CGSize fitting = [self.altTextView sizeThatFits:CGSizeMake(width - 12, CGFLOAT_MAX)];
        altHeight = MAX(minBoxHeight, MIN(maxBoxHeight, fitting.height));
    }
    // Update altTextView frame if visible
    if (!self.altTextView.hidden) {
        self.altTextView.frame = CGRectMake(10, 295, width, altHeight);
        self.altTextView.scrollEnabled = (altHeight >= maxBoxHeight);
        // Position transcript header below alt
        CGFloat transcriptHeaderY = CGRectGetMaxY(self.altTextView.frame) + 10;
        self.transcriptHeaderLabel.frame = CGRectMake(10, transcriptHeaderY, width, 18);
        CGFloat transcriptY = transcriptHeaderY + 20;
        // Transcript flexible height
        CGFloat transcriptHeight = minBoxHeight;
        if (self.transcriptTextView.text && self.transcriptTextView.text.length > 0) {
            CGSize fitting = [self.transcriptTextView sizeThatFits:CGSizeMake(width - 12, CGFLOAT_MAX)];
            transcriptHeight = MAX(minBoxHeight, MIN(maxBoxHeight, fitting.height));
        }
        self.transcriptTextView.frame = CGRectMake(10, transcriptY, width, transcriptHeight);
        self.transcriptTextView.scrollEnabled = (transcriptHeight >= maxBoxHeight);
        // Update scroll content size
        CGFloat bottom = CGRectGetMaxY(self.transcriptTextView.frame) + 20;
        self.scrollView.contentSize = CGSizeMake(320, MAX(500, bottom));
    } else {
        // Alt hidden, transcript moves up
        self.transcriptHeaderLabel.frame = CGRectMake(10, 275, width, 18);
        CGFloat transcriptHeight = minBoxHeight;
        if (self.transcriptTextView.text && self.transcriptTextView.text.length > 0) {
            CGSize fitting = [self.transcriptTextView sizeThatFits:CGSizeMake(width - 12, CGFLOAT_MAX)];
            transcriptHeight = MAX(minBoxHeight, MIN(maxBoxHeight, fitting.height));
        }
        self.transcriptTextView.frame = CGRectMake(10, 295, width, transcriptHeight);
        self.transcriptTextView.scrollEnabled = (transcriptHeight >= maxBoxHeight);
        CGFloat bottom = CGRectGetMaxY(self.transcriptTextView.frame) + 20;
        self.scrollView.contentSize = CGSizeMake(320, MAX(400, bottom));
    }
}

- (UIButton *)createButton:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button setFrame:frame];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    button.layer.cornerRadius = 6.0f;
    button.layer.borderColor = [UIColor grayColor].CGColor;
    button.layer.borderWidth = 1.0f;
    button.backgroundColor = [UIColor whiteColor];
    button.exclusiveTouch = YES;
    return button;
}

- (void)showExplanation {
    if (self.currentComicNumber <= 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Comic" message:@"No comic loaded to explain." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    ExplanationViewController *expVC = [[ExplanationViewController alloc] init];
    expVC.comicNumber = self.currentComicNumber;
    [self.navigationController pushViewController:expVC animated:YES];
}

- (void)loadComic:(NSInteger)number {
    if (number <= 0) number = 1;
    self.currentComicNumber = number;
    [self.activityIndicator startAnimating];
    self.comicImageView.image = nil;
    self.titleLabel.text = @"Loading...";
    self.dateLabel.text = @"";
    self.altTextView.text = @"";
    self.transcriptTextView.text = @"";
    [self layoutFlexibleBoxes];
    [[ComicManager sharedManager] fetchComic:number delegate:self];
}

- (void)showLatestComic {
    [self.activityIndicator startAnimating];
    self.titleLabel.text = @"Fetching latest...";
    self.dateLabel.text = @"";
    [[ComicManager sharedManager] fetchLatestComic:self];
}

- (void)showRandomComic {
    [self.activityIndicator startAnimating];
    self.titleLabel.text = @"Fetching random...";
    [[ComicManager sharedManager] fetchRandomComic:self];
}

- (void)showPreviousComic {
    NSInteger prev = (self.currentComicNumber > 1) ? self.currentComicNumber - 1 : 1;
    [self loadComic:prev];
}

- (void)showNextComic {
    [self loadComic:self.currentComicNumber + 1];
}

- (void)showJump {
    [self promptJumpComic];
}

- (void)toggleFavouriteCurrentComic {
    if (!self.currentComic) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Comic" message:@"No comic loaded to favourite." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    if ([Favourite isFavourite:self.currentComic.number]) {
        Favourite *fav = [[Favourite alloc] init];
        fav.comicNumber = self.currentComic.number;
        [fav remove];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Favourite Removed" message:[NSString stringWithFormat:@"Comic #%ld removed from favourites", (long)self.currentComic.number] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    } else {
        Favourite *fav = [[Favourite alloc] init];
        fav.comicNumber = self.currentComic.number;
        fav.note = self.currentComic.title;
        [fav add];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Favourite Added" message:[NSString stringWithFormat:@"Comic #%ld added to favourites", (long)self.currentComic.number] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)startDownloadCurrentComic {
    if (self.currentComic) {
        NSArray *completed = [[DownloadManager sharedManager] completedTasks];
        for (DownloadTask *t in completed) {
            if (t.comicNumber == self.currentComic.number) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Already Downloaded" message:[NSString stringWithFormat:@"Comic #%ld already downloaded.", (long)self.currentComic.number] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                return;
            }
        }
        [[DownloadManager sharedManager] downloadComic:self.currentComic.number delegate:self];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download Started" message:[NSString stringWithFormat:@"Download started for comic #%ld", (long)self.currentComic.number] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Comic" message:@"No comic loaded to download." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)promptJumpComic {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Jump to Comic" message:@"Enter comic number:" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Go", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 10;
    UITextField *tf = [alert textFieldAtIndex:0];
    if (tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.placeholder = [NSString stringWithFormat:@"%ld", (long)self.currentComicNumber];
    }
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 10 && buttonIndex == 1) {
        if (alertView.alertViewStyle != UIAlertViewStylePlainTextInput) return;
        UITextField *textField = [alertView textFieldAtIndex:0];
        if (!textField) return;
        NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSInteger number = [text integerValue];
        if (number > 0) {
            [self loadComic:number];
        } else {
            UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Invalid Number" message:@"Please enter a valid comic number." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [err show];
        }
    }
}

#pragma mark - ComicNetworkDelegate

- (void)comicFetched:(Comic *)comic {
    if (!comic) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentComic = comic;
        self.currentComicNumber = comic.number;
        self.titleLabel.text = comic.title ? comic.title : [NSString stringWithFormat:@"Comic #%ld", (long)comic.number];
        self.dateLabel.text = comic.dateString ? comic.dateString : @"Unknown date";
        self.altTextView.text = comic.altText ? comic.altText : @"No alt text available.";
        self.transcriptTextView.text = comic.transcript ? comic.transcript : @"No transcript available.";
        [self.activityIndicator stopAnimating];
        [self applySettings];
        [self layoutFlexibleBoxes];
        if (comic.imageURL && comic.imageURL.length > 0) {
            UIImage *cachedImage = [[ImageCache sharedCache] cachedImageForKey:comic.imageURL];
            if (cachedImage) {
                self.comicImageView.image = cachedImage;
            } else {
                [[ImageDownloader sharedDownloader] downloadImageFromURL:comic.imageURL delegate:self];
            }
        } else {
            self.comicImageView.image = nil;
        }
    });
}

- (void)comicFetchFailed:(NSInteger)number error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicator stopAnimating];
        NSInteger failedNumber = (number > 0) ? number : self.currentComicNumber;
        self.titleLabel.text = [NSString stringWithFormat:@"Failed to load #%ld", (long)failedNumber];
        self.dateLabel.text = error ? [error localizedDescription] : @"Offline or error.";
        Comic *cached = [[ComicManager sharedManager] cachedComic:failedNumber];
        if (cached) {
            self.currentComic = cached;
            self.currentComicNumber = cached.number;
            self.titleLabel.text = cached.title ? cached.title : [NSString stringWithFormat:@"Comic #%ld", (long)cached.number];
            self.dateLabel.text = cached.dateString ? cached.dateString : @"Cached version";
            self.altTextView.text = cached.altText ? cached.altText : @"";
            self.transcriptTextView.text = cached.transcript ? cached.transcript : @"";
            if (cached.imageURL) {
                UIImage *cachedImage = [[ImageCache sharedCache] cachedImageForKey:cached.imageURL];
                if (cachedImage) self.comicImageView.image = cachedImage;
            }
        }
        [self applySettings];
        [self layoutFlexibleBoxes];
    });
}

#pragma mark - ImageDownloaderDelegate

- (void)imageDownloader:(id)downloader didDownloadImage:(UIImage *)image forURL:(NSString *)urlString error:(NSError *)error {
    if (image && [self.currentComic.imageURL isEqualToString:urlString]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.comicImageView.image = image;
        });
    }
}

#pragma mark - ExplanationProviderDelegate (for transcript fallback)

- (void)provider:(id)provider didFetchExplanation:(id)explanation error:(NSError *)error {
    // Handle explanation transcript fallback
    if ([explanation respondsToSelector:@selector(transcript)] && [explanation respondsToSelector:@selector(body)]) {
        NSString *trans = [explanation valueForKey:@"transcript"];
        if (trans && trans.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL currentEmpty = (self.transcriptTextView.text.length == 0 ||
                                     [self.transcriptTextView.text isEqualToString:@"No transcript available."]);
                if (currentEmpty) {
                    self.transcriptTextView.text = trans;
                    [self layoutFlexibleBoxes];
                }
            });
        }
    }
}

#pragma mark - DownloadDelegateProtocol

- (void)downloadTask:(DownloadTask *)task didUpdateProgress:(float)progress {}
- (void)downloadTaskDidComplete:(DownloadTask *)task {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download Complete" message:[NSString stringWithFormat:@"Comic #%ld downloaded", (long)task.comicNumber] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    });
}
- (void)downloadTaskDidFail:(DownloadTask *)task {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download Failed" message:[NSString stringWithFormat:@"Failed to download comic #%ld after %ld retries", (long)task.comicNumber, (long)task.retryCount] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [[ImageCache sharedCache] clearCache];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

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

@interface ComicsViewController () <DownloadDelegateProtocol>
@property (nonatomic, assign) NSInteger currentComicNumber;
@property (nonatomic, strong) UIScrollView *scrollView;
@end

@implementation ComicsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Comics";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.currentComicNumber = 1;

    // Navigation bar buttons
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithTitle:@"Latest" style:UIBarButtonItemStyleDone target:self action:@selector(showLatestComic)],
        [[UIBarButtonItem alloc] initWithTitle:@"Explain" style:UIBarButtonItemStyleBordered target:self action:@selector(showExplanation)]
    ];

    // Scroll view to allow scrolling all content
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 320, 416)];
    self.scrollView.contentSize = CGSizeMake(320, 650);
    self.scrollView.showsVerticalScrollIndicator = YES;
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.scrollView];

    // Title label
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 300, 30)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    [self.scrollView addSubview:self.titleLabel];

    // Comic image
    self.comicImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 45, 300, 220)];
    self.comicImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.comicImageView.backgroundColor = [UIColor whiteColor];
    self.comicImageView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.comicImageView.layer.borderWidth = 1.0f;
    [self.scrollView addSubview:self.comicImageView];

    // Date label
    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 270, 300, 20)];
    self.dateLabel.font = [UIFont systemFontOfSize:12.0f];
    self.dateLabel.textColor = [UIColor darkGrayColor];
    self.dateLabel.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:self.dateLabel];

    // Alt text view (scrollable, larger)
    self.altTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 295, 300, 100)];
    self.altTextView.font = [UIFont systemFontOfSize:13.0f];
    self.altTextView.editable = NO;
    self.altTextView.scrollEnabled = YES;
    self.altTextView.textColor = [UIColor darkGrayColor];
    [self.scrollView addSubview:self.altTextView];

    // Transcript text view (scrollable, larger)
    self.transcriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 400, 300, 100)];
    self.transcriptTextView.font = [UIFont systemFontOfSize:12.0f];
    self.transcriptTextView.editable = NO;
    self.transcriptTextView.scrollEnabled = YES;
    [self.scrollView addSubview:self.transcriptTextView];

    // Activity indicator
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.activityIndicator setCenter:CGPointMake(160, 160)];
    [self.activityIndicator startAnimating];
    [self.scrollView addSubview:self.activityIndicator];

    // Control buttons (visible below transcript)
    CGFloat buttonY = 515;
    CGFloat buttonWidth = 55;
    CGFloat spacing = 5;
    CGFloat totalWidth = buttonWidth * 5 + spacing * 4;
    CGFloat startX = (320 - totalWidth) / 2;

    self.prevButton = [self createButton:@"Prev" frame:CGRectMake(startX, buttonY, buttonWidth, 36) action:@selector(showPreviousComic)];
    self.nextButton = [self createButton:@"Next" frame:CGRectMake(startX + buttonWidth + spacing, buttonY, buttonWidth, 36) action:@selector(showNextComic)];
    self.randomButton = [self createButton:@"Random" frame:CGRectMake(startX + (buttonWidth + spacing) * 2, buttonY, buttonWidth, 36) action:@selector(showRandomComic)];
    UIButton *favBtn = [self createButton:@"Fav" frame:CGRectMake(startX + (buttonWidth + spacing) * 3, buttonY, buttonWidth, 36) action:@selector(toggleFavouriteCurrentComic)];
    [self.scrollView addSubview:favBtn];
    self.jumpButton = [self createButton:@"Jump" frame:CGRectMake(startX + (buttonWidth + spacing) * 4, buttonY, buttonWidth, 36) action:@selector(promptJumpComic)];

    // Download button (top right of image)
    UIButton *downloadBtn = [self createButton:@"Download" frame:CGRectMake(230, 5, 70, 30) action:@selector(startDownloadCurrentComic)];
    [self.scrollView addSubview:downloadBtn];

    [self.scrollView addSubview:self.prevButton];
    [self.scrollView addSubview:self.nextButton];
    [self.scrollView addSubview:self.randomButton];
    [self.scrollView addSubview:self.jumpButton];

    // Apply settings
    [self applySettings];

    // Load latest on startup
    [self showLatestComic];
}

- (void)applySettings {
    Settings *settings = [[SettingsManager sharedInstance] currentSettings];
    self.altTextView.hidden = !settings.showAltText;
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
    return button;
}

- (void)showExplanation {
    ExplanationViewController *expVC = [[ExplanationViewController alloc] init];
    expVC.comicNumber = self.currentComicNumber;
    [self.navigationController pushViewController:expVC animated:YES];
}

- (void)loadComic:(NSInteger)number {
    self.currentComicNumber = number;
    [self.activityIndicator startAnimating];
    self.comicImageView.image = nil;
    self.titleLabel.text = @"Loading...";
    self.dateLabel.text = @"";
    self.altTextView.text = @"";
    self.transcriptTextView.text = @"";

    [[ComicManager sharedManager] fetchComic:number delegate:self];
}

- (void)showLatestComic {
    [self.activityIndicator startAnimating];
    self.titleLabel.text = @"Fetching latest...";
    [[ComicManager sharedManager] fetchLatestComic:self];
}

- (void)showRandomComic {
    int randomNumber = arc4random_uniform(2500) + 1;
    [self loadComic:randomNumber];
}

- (void)showPreviousComic {
    NSInteger prev = (self.currentComicNumber > 1) ? self.currentComicNumber - 1 : 1;
    [self loadComic:prev];
}

- (void)showNextComic {
    [self loadComic:self.currentComicNumber + 1];
}

- (void)toggleFavouriteCurrentComic {
    if (self.currentComic) {
        if ([Favourite isFavourite:self.currentComic.number]) {
            Favourite *fav = [[Favourite alloc] init];
            fav.comicNumber = self.currentComic.number;
            [fav remove];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Favourite Removed" message:[NSString stringWithFormat:@"Comic #%ld removed from favourites", (long)self.currentComic.number] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        } else {
            Favourite *fav = [[Favourite alloc] init];
            fav.comicNumber = self.currentComic.number;
            [fav add];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Favourite Added" message:[NSString stringWithFormat:@"Comic #%ld added to favourites", (long)self.currentComic.number] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    }
}

- (void)startDownloadCurrentComic {
    if (self.currentComic) {
        [[DownloadManager sharedManager] downloadComic:self.currentComic.number delegate:self];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download Started" message:[NSString stringWithFormat:@"Download started for comic #%ld", (long)self.currentComic.number] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)promptJumpComic {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Jump to Comic" message:@"Enter comic number:" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Go", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        UITextField *textField = [alertView textFieldAtIndex:0];
        NSString *text = textField.text;
        NSInteger number = [text intValue];
        if (number > 0) {
            [self loadComic:number];
        } else {
            [self showLatestComic];
        }
    }
}

#pragma mark - ComicNetworkDelegate

- (void)comicFetched:(Comic *)comic {
    self.currentComic = comic;
    self.currentComicNumber = comic.number;
    self.titleLabel.text = comic.title ? comic.title : @"Untitled";

    NSString *dateStr = comic.dateString ? comic.dateString : @"Unknown date";
    self.dateLabel.text = dateStr;

    self.altTextView.text = comic.altText ? comic.altText : @"No alt text available.";
    self.transcriptTextView.text = comic.transcript ? comic.transcript : @"No transcript available.";

    [self.activityIndicator stopAnimating];
    [self applySettings];

    // Load image
    if (comic.imageURL && comic.imageURL.length > 0) {
        UIImage *cachedImage = [[ImageCache sharedCache] cachedImageForKey:comic.imageURL];
        if (cachedImage) {
            self.comicImageView.image = cachedImage;
        } else {
            [[ImageDownloader sharedDownloader] downloadImageFromURL:comic.imageURL delegate:self];
        }
    }
}

- (void)comicFetchFailed:(NSInteger)number error:(NSError *)error {
    [self.activityIndicator stopAnimating];
    self.titleLabel.text = [NSString stringWithFormat:@"Failed to load #%ld", (long)number];
    self.dateLabel.text = @"Offline or error.";
    Comic *cached = [[ComicManager sharedManager] cachedComic:self.currentComicNumber];
    if (cached) {
        self.currentComic = cached;
        self.titleLabel.text = cached.title ? cached.title : @"Untitled";
        self.dateLabel.text = cached.dateString ? cached.dateString : @"";
        self.altTextView.text = cached.altText ? cached.altText : @"";
        self.transcriptTextView.text = cached.transcript ? cached.transcript : @"";
    }
    [self applySettings];
}

#pragma mark - ImageDownloaderDelegate

- (void)imageDownloader:(id)downloader didDownloadImage:(UIImage *)image forURL:(NSString *)urlString error:(NSError *)error {
    if (image) {
        self.comicImageView.image = image;
    }
}

#pragma mark - DownloadDelegateProtocol

- (void)downloadTask:(DownloadTask *)task didUpdateProgress:(float)progress {
    // Handled silently for skeleton.
}

- (void)downloadTaskDidComplete:(DownloadTask *)task {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download Complete" message:[NSString stringWithFormat:@"Comic #%ld downloaded", (long)task.comicNumber] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void)downloadTaskDidFail:(DownloadTask *)task {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download Failed" message:[NSString stringWithFormat:@"Failed to download comic #%ld after retries", (long)task.comicNumber] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void)dealloc {
    // ARC manages memory; explicit cleanup not required.
}

@end

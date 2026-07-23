#import "ComicDetailViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "Models/Comic.h"
#import "Models/Explanation.h"
#import "Managers/ComicManager.h"
#import "Managers/ImageCache.h"
#import "Managers/ImageDownloader.h"
#import "Managers/ExplanationProvider.h"
#import "Managers/ExplanationCache.h"
#import "Managers/SettingsManager.h"

@interface ComicDetailViewController () <ComicNetworkDelegate, ImageDownloaderDelegate, ExplanationProviderDelegate>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *altHeaderLabel;
@property (nonatomic, strong) UILabel *transcriptHeaderLabel;
@property (nonatomic, strong) UILabel *explanationHeaderLabel;
@property (nonatomic, strong) UITextView *altTextView;
@property (nonatomic, strong) UITextView *transcriptTextView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UIScrollView *scrollView;
@end

@implementation ComicDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"Comic #%ld", (long)self.comicNumber];
    self.view.backgroundColor = [UIColor colorWithRed:0.937f green:0.937f blue:0.957f alpha:1.0f];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 320, 416)];
    self.scrollView.contentSize = CGSizeMake(320, 700);
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

    self.comicImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 45, 300, 220)];
    self.comicImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.comicImageView.backgroundColor = [UIColor whiteColor];
    self.comicImageView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.comicImageView.layer.borderWidth = 1.0f;
    self.comicImageView.layer.cornerRadius = 4.0f;
    self.comicImageView.clipsToBounds = YES;
    [self.scrollView addSubview:self.comicImageView];

    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 270, 300, 20)];
    self.dateLabel.font = [UIFont systemFontOfSize:12.0f];
    self.dateLabel.textColor = [UIColor darkGrayColor];
    self.dateLabel.textAlignment = NSTextAlignmentCenter;
    self.dateLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.dateLabel];

    // Alt text section
    self.altHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 295, 300, 18)];
    self.altHeaderLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    self.altHeaderLabel.textColor = [UIColor darkGrayColor];
    self.altHeaderLabel.text = @"Alt Text:";
    [self.scrollView addSubview:self.altHeaderLabel];

    self.altTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 315, 300, 70)];
    self.altTextView.font = [UIFont systemFontOfSize:13.0f];
    self.altTextView.editable = NO;
    self.altTextView.scrollEnabled = NO;
    self.altTextView.textColor = [UIColor darkGrayColor];
    self.altTextView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0];
    self.altTextView.layer.cornerRadius = 6.0f;
    self.altTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.altTextView.layer.borderWidth = 0.5f;
    self.altTextView.contentInset = UIEdgeInsetsMake(6, 6, 6, 6);
    [self.scrollView addSubview:self.altTextView];

    // Transcript section under alt text
    self.transcriptHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 395, 300, 18)];
    self.transcriptHeaderLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    self.transcriptHeaderLabel.textColor = [UIColor darkGrayColor];
    self.transcriptHeaderLabel.text = @"Transcript:";
    [self.scrollView addSubview:self.transcriptHeaderLabel];

    self.transcriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 415, 300, 70)];
    self.transcriptTextView.font = [UIFont systemFontOfSize:12.0f];
    self.transcriptTextView.editable = NO;
    self.transcriptTextView.scrollEnabled = NO;
    self.transcriptTextView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0];
    self.transcriptTextView.layer.cornerRadius = 6.0f;
    self.transcriptTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.transcriptTextView.layer.borderWidth = 0.5f;
    self.transcriptTextView.contentInset = UIEdgeInsetsMake(6, 6, 6, 6);
    [self.scrollView addSubview:self.transcriptTextView];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.activityIndicator setCenter:CGPointMake(160, 150)];
    self.activityIndicator.hidesWhenStopped = YES;
    [self.activityIndicator startAnimating];
    [self.scrollView addSubview:self.activityIndicator];

    // Explanation header
    self.explanationHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 495, 300, 18)];
    self.explanationHeaderLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    self.explanationHeaderLabel.textColor = [UIColor darkGrayColor];
    self.explanationHeaderLabel.text = @"Explanation:";
    [self.scrollView addSubview:self.explanationHeaderLabel];

    self.explanationTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 515, 300, 120)];
    self.explanationTextView.font = [UIFont systemFontOfSize:14.0f];
    self.explanationTextView.editable = NO;
    self.explanationTextView.scrollEnabled = NO;
    self.explanationTextView.dataDetectorTypes = UIDataDetectorTypeLink;
    self.explanationTextView.backgroundColor = [UIColor whiteColor];
    self.explanationTextView.layer.cornerRadius = 6.0f;
    self.explanationTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.explanationTextView.layer.borderWidth = 0.5f;
    self.explanationTextView.contentInset = UIEdgeInsetsMake(8, 8, 8, 8);
    [self.scrollView addSubview:self.explanationTextView];

    [self applySettings];
    [self loadComic:self.comicNumber];
}

- (void)applySettings {
    Settings *settings = [[SettingsManager sharedInstance] currentSettings];
    self.altTextView.hidden = !settings.showAltText;
    self.altHeaderLabel.hidden = !settings.showAltText;
    [self layoutFlexibleBoxes];
}

- (void)layoutFlexibleBoxes {
    CGFloat minHeight = 50.0f;
    CGFloat maxHeight = 140.0f;
    CGFloat width = 300.0f;

    CGFloat y = 295;
    if (!self.altTextView.hidden) {
        self.altHeaderLabel.frame = CGRectMake(10, y, width, 18);
        y += 20;
        CGFloat altHeight = minHeight;
        if (self.altTextView.text.length > 0) {
            CGSize fit = [self.altTextView sizeThatFits:CGSizeMake(width - 12, CGFLOAT_MAX)];
            altHeight = MAX(minHeight, MIN(maxHeight, fit.height));
        }
        self.altTextView.frame = CGRectMake(10, y, width, altHeight);
        self.altTextView.scrollEnabled = (altHeight >= maxHeight);
        y = CGRectGetMaxY(self.altTextView.frame) + 12;
    } else {
        y = 295;
    }

    self.transcriptHeaderLabel.frame = CGRectMake(10, y, width, 18);
    y += 20;
    CGFloat transcriptHeight = minHeight;
    if (self.transcriptTextView.text.length > 0) {
        CGSize fit = [self.transcriptTextView sizeThatFits:CGSizeMake(width - 12, CGFLOAT_MAX)];
        transcriptHeight = MAX(minHeight, MIN(maxHeight, fit.height));
    }
    self.transcriptTextView.frame = CGRectMake(10, y, width, transcriptHeight);
    self.transcriptTextView.scrollEnabled = (transcriptHeight >= maxHeight);
    y = CGRectGetMaxY(self.transcriptTextView.frame) + 12;

    self.explanationHeaderLabel.frame = CGRectMake(10, y, width, 18);
    y += 20;
    CGFloat expHeight = 120.0f;
    if (self.explanationTextView.text.length > 0) {
        CGSize fit = [self.explanationTextView sizeThatFits:CGSizeMake(width - 16, CGFLOAT_MAX)];
        expHeight = MAX(80.0f, MIN(300.0f, fit.height));
    }
    self.explanationTextView.frame = CGRectMake(10, y, width, expHeight);
    self.explanationTextView.scrollEnabled = (expHeight >= 300.0f);
    y = CGRectGetMaxY(self.explanationTextView.frame) + 20;

    self.scrollView.contentSize = CGSizeMake(320, MAX(650, y));
}

- (void)loadComic:(NSInteger)number {
    if (number <= 0) number = 1;
    [self.activityIndicator startAnimating];
    self.titleLabel.text = @"Loading...";
    self.dateLabel.text = @"";
    self.altTextView.text = @"";
    self.transcriptTextView.text = @"";
    self.explanationTextView.text = @"Loading explanation...";
    self.comicImageView.image = nil;
    [self layoutFlexibleBoxes];
    [[ComicManager sharedManager] fetchComic:number delegate:self];
}

- (void)comicFetched:(Comic *)comic {
    if (!comic) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.title = [NSString stringWithFormat:@"Comic #%ld", (long)comic.number];
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
        }
        Explanation *cached = [[ExplanationCache sharedCache] cachedExplanationForComic:comic.number];
        if (cached) {
            self.explanationTextView.text = [cached formattedBody];
            [self layoutFlexibleBoxes];
        } else {
            [[ExplanationProvider sharedProvider] fetchExplanationForComic:comic.number delegate:self];
        }
    });
}

- (void)comicFetchFailed:(NSInteger)number error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicator stopAnimating];
        self.titleLabel.text = [NSString stringWithFormat:@"Failed to load #%ld", (long)number];
        self.dateLabel.text = error ? [error localizedDescription] : @"Offline or error.";
        Comic *cached = [[ComicManager sharedManager] cachedComic:number];
        if (cached) {
            self.title = [NSString stringWithFormat:@"Comic #%ld (Cached)", (long)cached.number];
            self.titleLabel.text = cached.title ? cached.title : [NSString stringWithFormat:@"Comic #%ld", (long)cached.number];
            self.dateLabel.text = cached.dateString ? [NSString stringWithFormat:@"%@ (Cached)", cached.dateString] : @"Cached";
            self.altTextView.text = cached.altText ? cached.altText : @"";
            self.transcriptTextView.text = cached.transcript ? cached.transcript : @"";
            if (cached.imageURL) {
                UIImage *cachedImage = [[ImageCache sharedCache] cachedImageForKey:cached.imageURL];
                if (cachedImage) self.comicImageView.image = cachedImage;
            }
        }
        self.explanationTextView.text = @"No explanation available offline.";
        [self applySettings];
        [self layoutFlexibleBoxes];
    });
}

- (void)imageDownloader:(id)downloader didDownloadImage:(UIImage *)image forURL:(NSString *)urlString error:(NSError *)error {
    if (image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.comicImageView.image = image;
        });
    }
}

#pragma mark - ExplanationProviderDelegate

- (void)provider:(id)provider didFetchExplanation:(Explanation *)explanation error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (explanation) {
            self.explanationTextView.text = [explanation formattedBody];
            // If transcript from explainxkcd is available and current transcript is empty or is the default "No transcript"
            // use the wiki transcript as it is often more detailed
            if (explanation.transcript && explanation.transcript.length > 0) {
                BOOL currentEmpty = (self.transcriptTextView.text.length == 0 ||
                                     [self.transcriptTextView.text isEqualToString:@"No transcript available."] ||
                                     [self.transcriptTextView.text isEqualToString:@"No transcript available offline."]);
                if (currentEmpty || [self.transcriptTextView.text rangeOfString:@"No transcript"].location != NSNotFound) {
                    self.transcriptTextView.text = explanation.transcript;
                } else {
                    // Append wiki transcript if different and not already present
                    if (![self.transcriptTextView.text isEqualToString:explanation.transcript]) {
                        NSString *combined = [NSString stringWithFormat:@"%@\n\n--- Wiki Transcript ---\n%@", self.transcriptTextView.text, explanation.transcript];
                        self.transcriptTextView.text = combined;
                    }
                }
            }
        } else {
            if (error) {
                self.explanationTextView.text = [NSString stringWithFormat:@"No explanation available.\n%@", [error localizedDescription]];
            } else {
                self.explanationTextView.text = @"No explanation available.";
            }
        }
        [self layoutFlexibleBoxes];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [[ImageCache sharedCache] clearCache];
}

- (void)dealloc {
    [[ImageDownloader sharedDownloader] cancelDownloadForURL:nil];
}

@end

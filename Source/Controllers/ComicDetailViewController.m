#import "ComicDetailViewController.h"
#import "Managers/ComicManager.h"
#import "Managers/ImageCache.h"
#import "Managers/ImageDownloader.h"
#import "Managers/ExplanationProvider.h"
#import "Managers/ExplanationCache.h"

@interface ComicDetailViewController () <ComicNetworkDelegate, ImageDownloaderDelegate, ExplanationProviderDelegate>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UITextView *altTextView;
@property (nonatomic, strong) UITextView *transcriptTextView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@end

@implementation ComicDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"Comic #%ld", (long)self.comicNumber];
    self.view.backgroundColor = [UIColor whiteColor];

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 320, 416)];
    scrollView.contentSize = CGSizeMake(320, 650);
    scrollView.showsVerticalScrollIndicator = YES;
    [self.view addSubview:scrollView];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 300, 30)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    [scrollView addSubview:self.titleLabel];

    self.comicImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 45, 300, 220)];
    self.comicImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.comicImageView.backgroundColor = [UIColor whiteColor];
    self.comicImageView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.comicImageView.layer.borderWidth = 1.0f;
    [scrollView addSubview:self.comicImageView];

    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 270, 300, 20)];
    self.dateLabel.font = [UIFont systemFontOfSize:12.0f];
    self.dateLabel.textColor = [UIColor darkGrayColor];
    self.dateLabel.textAlignment = NSTextAlignmentCenter;
    [scrollView addSubview:self.dateLabel];

    self.altTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 295, 300, 100)];
    self.altTextView.font = [UIFont systemFontOfSize:13.0f];
    self.altTextView.editable = NO;
    self.altTextView.scrollEnabled = YES;
    self.altTextView.textColor = [UIColor darkGrayColor];
    [scrollView addSubview:self.altTextView];

    self.transcriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 400, 300, 100)];
    self.transcriptTextView.font = [UIFont systemFontOfSize:12.0f];
    self.transcriptTextView.editable = NO;
    self.transcriptTextView.scrollEnabled = YES;
    [scrollView addSubview:self.transcriptTextView];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.activityIndicator setCenter:CGPointMake(160, 160)];
    [self.activityIndicator startAnimating];
    [scrollView addSubview:self.activityIndicator];

    self.explanationTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 510, 300, 120)];
    self.explanationTextView.font = [UIFont systemFontOfSize:14.0f];
    self.explanationTextView.editable = NO;
    self.explanationTextView.scrollEnabled = YES;
    self.explanationTextView.dataDetectorTypes = UIDataDetectorTypeLink;
    [scrollView addSubview:self.explanationTextView];

    [self loadComic:self.comicNumber];
}

- (void)loadComic:(NSInteger)number {
    [self.activityIndicator startAnimating];
    self.titleLabel.text = @"Loading...";
    self.dateLabel.text = @"";
    self.altTextView.text = @"";
    self.transcriptTextView.text = @"";
    self.explanationTextView.text = @"Loading explanation...";
    [[ComicManager sharedManager] fetchComic:number delegate:self];
}

- (void)comicFetched:(Comic *)comic {
    self.title = [NSString stringWithFormat:@"Comic #%ld", (long)comic.number];
    self.titleLabel.text = comic.title ? comic.title : @"Untitled";
    self.dateLabel.text = comic.dateString ? comic.dateString : @"Unknown date";
    self.altTextView.text = comic.altText ? comic.altText : @"No alt text available.";
    self.transcriptTextView.text = comic.transcript ? comic.transcript : @"No transcript available.";
    [self.activityIndicator stopAnimating];

    if (comic.imageURL && comic.imageURL.length > 0) {
        UIImage *cachedImage = [[ImageCache sharedCache] cachedImageForKey:comic.imageURL];
        if (cachedImage) {
            self.comicImageView.image = cachedImage;
        } else {
            [[ImageDownloader sharedDownloader] downloadImageFromURL:comic.imageURL delegate:self];
        }
    }

    // Load explanation
    Explanation *cached = [[ExplanationCache sharedCache] cachedExplanationForComic:comic.number];
    if (cached) {
        self.explanationTextView.text = [cached formattedBody];
    } else {
        [[ExplanationProvider sharedProvider] fetchExplanationForComic:comic.number delegate:self];
    }
}

- (void)comicFetchFailed:(NSInteger)number error:(NSError *)error {
    [self.activityIndicator stopAnimating];
    self.titleLabel.text = [NSString stringWithFormat:@"Failed to load #%ld", (long)number];
    self.dateLabel.text = @"Offline or error.";
    Comic *cached = [[ComicManager sharedManager] cachedComic:number];
    if (cached) {
        self.titleLabel.text = cached.title ? cached.title : @"Untitled";
        self.altTextView.text = cached.altText ? cached.altText : @"";
        self.transcriptTextView.text = cached.transcript ? cached.transcript : @"";
    }
}

- (void)imageDownloader:(id)downloader didDownloadImage:(UIImage *)image forURL:(NSString *)urlString error:(NSError *)error {
    if (image) {
        self.comicImageView.image = image;
    }
}

#pragma mark - ExplanationProviderDelegate

- (void)provider:(id)provider didFetchExplanation:(Explanation *)explanation error:(NSError *)error {
    if (explanation) {
        self.explanationTextView.text = [explanation formattedBody];
    } else {
        self.explanationTextView.text = @"No explanation available.";
    }
}

@end

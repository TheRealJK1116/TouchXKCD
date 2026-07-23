#import "ExplanationViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "Managers/ExplanationProvider.h"
#import "Managers/ExplanationCache.h"
#import "Managers/ComicManager.h"
#import "Models/Explanation.h"
#import "Models/Comic.h"

@interface ExplanationViewController () <ExplanationProviderDelegate>
@property (nonatomic, strong) Explanation *currentExplanation;
@end

@implementation ExplanationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"Explain #%ld", (long)self.comicNumber];
    self.view.backgroundColor = [UIColor whiteColor];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 300, 20)];
    self.statusLabel.font = [UIFont systemFontOfSize:12.0f];
    self.statusLabel.textColor = [UIColor darkGrayColor];
    self.statusLabel.text = @"Loading explanation...";
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];

    self.explanationView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 300, 320)];
    self.explanationView.font = [UIFont systemFontOfSize:14.0f];
    self.explanationView.editable = NO;
    self.explanationView.dataDetectorTypes = UIDataDetectorTypeLink;
    self.explanationView.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1.0];
    self.explanationView.layer.cornerRadius = 4.0f;
    self.explanationView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.explanationView.layer.borderWidth = 0.5f;
    self.explanationView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.explanationView];

    self.loadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [self.loadButton setTitle:@"Reload Explanation" forState:UIControlStateNormal];
    self.loadButton.frame = CGRectMake(60, 370, 200, 36);
    self.loadButton.layer.cornerRadius = 6.0f;
    self.loadButton.layer.borderColor = [UIColor grayColor].CGColor;
    self.loadButton.layer.borderWidth = 1.0f;
    self.loadButton.backgroundColor = [UIColor whiteColor];
    [self.loadButton addTarget:self action:@selector(loadExplanation) forControlEvents:UIControlEventTouchUpInside];
    self.loadButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.loadButton];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear Cache" style:UIBarButtonItemStyleBordered target:self action:@selector(clearCache)];

    [self loadExplanation];
}

- (void)clearCache {
    [[ExplanationCache sharedCache] clearCache];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cache Cleared" message:@"Explanation cache cleared, reload to fetch fresh." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    self.statusLabel.text = @"Cache cleared";
    self.explanationView.text = @"Cache cleared. Tap Reload to fetch again.";
    self.currentExplanation = nil;
}

- (void)loadExplanation {
    if (self.comicNumber <= 0) {
        self.statusLabel.text = @"Invalid comic number";
        self.explanationView.text = @"No comic number provided.";
        return;
    }
    self.statusLabel.text = @"Checking cache...";
    Explanation *cached = [[ExplanationCache sharedCache] cachedExplanationForComic:self.comicNumber];
    if (cached) {
        self.currentExplanation = cached;
        self.explanationView.text = [cached formattedBody];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateStyle:NSDateFormatterShortStyle];
        [df setTimeStyle:NSDateFormatterShortStyle];
        NSString *dateStr = cached.lastUpdated ? [df stringFromDate:cached.lastUpdated] : @"Unknown date";
        self.statusLabel.text = [NSString stringWithFormat:@"Cached - %@ (tap Reload for fresh)", dateStr];
        // Also fetch fresh in background to update cache
        [[ExplanationProvider sharedProvider] fetchExplanationForComic:self.comicNumber delegate:self];
    } else {
        self.statusLabel.text = @"Fetching explanation from explainxkcd.com...";
        self.explanationView.text = @"";
        [[ExplanationProvider sharedProvider] fetchExplanationForComic:self.comicNumber delegate:self];
    }
}

#pragma mark - ExplanationProviderDelegate

- (void)provider:(id)provider didFetchExplanation:(Explanation *)explanation error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (explanation) {
            self.currentExplanation = explanation;
            self.explanationView.text = [explanation formattedBody];
            if (error) {
                self.statusLabel.text = [NSString stringWithFormat:@"Fetched with warning: %@ (showing cached or partial)", [error localizedDescription]];
            } else {
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                [df setDateStyle:NSDateFormatterShortStyle];
                [df setTimeStyle:NSDateFormatterShortStyle];
                NSString *dateStr = explanation.lastUpdated ? [df stringFromDate:explanation.lastUpdated] : @"now";
                self.statusLabel.text = [NSString stringWithFormat:@"Fetched - %@ - %ld chars", dateStr, (long)[explanation.body length]];
            }
        } else {
            if (error) {
                self.statusLabel.text = [NSString stringWithFormat:@"Failed: %@", [error localizedDescription]];
                self.explanationView.text = [NSString stringWithFormat:@"No explanation available for comic #%ld.\n\nError: %@\n\nPlease check network connection.", (long)self.comicNumber, [error localizedDescription]];
            } else {
                self.statusLabel.text = @"No explanation found.";
                self.explanationView.text = @"No explanation available for this comic.";
            }
        }
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end

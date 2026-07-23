#import "ExplanationViewController.h"
#import "Managers/ExplanationProvider.h"
#import "Managers/ExplanationCache.h"
#import "Managers/ComicManager.h"
#import "Models/Explanation.h"

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
    [self.view addSubview:self.statusLabel];

    self.explanationView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 300, 350)];
    self.explanationView.font = [UIFont systemFontOfSize:14.0f];
    self.explanationView.editable = NO;
    self.explanationView.dataDetectorTypes = UIDataDetectorTypeLink;
    [self.view addSubview:self.explanationView];

    self.loadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [self.loadButton setTitle:@"Load Explanation" forState:UIControlStateNormal];
    self.loadButton.frame = CGRectMake(80, 400, 160, 36);
    [self.loadButton addTarget:self action:@selector(loadExplanation) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loadButton];

    [self loadExplanation];
}

- (void)loadExplanation {
    self.statusLabel.text = @"Fetching explanation...";
    Explanation *cached = [[ExplanationCache sharedCache] cachedExplanationForComic:self.comicNumber];
    if (cached) {
        self.currentExplanation = cached;
        self.explanationView.text = [cached formattedBody];
        self.statusLabel.text = [NSString stringWithFormat:@"Cached - %@", [cached.lastUpdated description]];
    } else {
        [[ExplanationProvider sharedProvider] fetchExplanationForComic:self.comicNumber delegate:self];
    }
}

#pragma mark - ExplanationProviderDelegate

- (void)provider:(id)provider didFetchExplanation:(Explanation *)explanation error:(NSError *)error {
    if (explanation) {
        self.currentExplanation = explanation;
        self.explanationView.text = [explanation formattedBody];
        if (error) {
            self.statusLabel.text = @"Fetched with errors (cached may exist)";
        } else {
            self.statusLabel.text = [NSString stringWithFormat:@"Fetched - %@", [explanation.lastUpdated description]];
        }
    } else {
        if (error) {
            self.statusLabel.text = @"Failed to load explanation. No cached version found.";
            self.explanationView.text = @"No explanation available for this comic.\n\nPlease check your network connection or try again later.";
        }
    }
}

@end

#import "ExplanationProvider.h"
#import "ExplanationCache.h"
#import "Models/Explanation.h"

@interface ExplanationParserStrategy : NSObject
- (Explanation *)parseData:(NSData *)data forComic:(NSInteger)comicNumber error:(NSError **)error;
@end

@interface ExplanationParserStrategy ()
@end

@implementation ExplanationParserStrategy
- (NSString *)stripHTML:(NSString *)html {
    if (!html) return @"";
    // Remove HTML tags
    NSRange r;
    NSString *stripped = html;
    while ((r = [stripped rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound) {
        stripped = [stripped stringByReplacingCharactersInRange:r withString:@""];
    }
    // Decode basic HTML entities
    stripped = [stripped stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
    stripped = [stripped stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    stripped = [stripped stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    stripped = [stripped stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    stripped = [stripped stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "];
    return stripped;
}
- (Explanation *)parseData:(NSData *)data forComic:(NSInteger)comicNumber error:(NSError **)error {
    // Try JSON first
    NSError *jsonError = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!jsonError && dict) {
        Explanation *exp = [[Explanation alloc] init];
        exp.comicNumber = comicNumber;
        exp.body = [dict objectForKey:@"body"] ? [dict objectForKey:@"body"] : @"";
        NSArray *refs = [dict objectForKey:@"references"];
        exp.references = refs ? refs : [NSArray array];
        exp.author = [dict objectForKey:@"author"] ? [dict objectForKey:@"author"] : @"";
        exp.lastUpdated = [NSDate date];
        return exp;
    }
    // Fallback: treat as plain text / HTML snippet
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    NSString *stripped = [self stripHTML:text ? text : @""];
    Explanation *exp = [[Explanation alloc] init];
    exp.comicNumber = comicNumber;
    exp.body = stripped ? stripped : @"";
    exp.references = [NSArray array];
    exp.author = @"Unknown";
    exp.lastUpdated = [NSDate date];
    return exp;
}
@end

@interface ExplanationProvider () <NSURLConnectionDataDelegate, NSURLConnectionDelegate>
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) NSInteger pendingComicNumber;
@property (nonatomic, assign) id<ExplanationProviderDelegate> pendingDelegate;
@property (nonatomic, strong) ExplanationParserStrategy *parserStrategy;
@end

@implementation ExplanationProvider

+ (instancetype)sharedProvider {
    static ExplanationProvider *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.parserStrategy = [[ExplanationParserStrategy alloc] init];
    });
    return shared;
}

- (void)fetchExplanationForComic:(NSInteger)comicNumber delegate:(id<ExplanationProviderDelegate>)delegate {
    // Check cache first
    Explanation *cached = [[ExplanationCache sharedCache] cachedExplanationForComic:comicNumber];
    if (cached) {
        if ([delegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
            [delegate provider:self didFetchExplanation:cached error:nil];
        }
    }

    // Fetch explanation from XKCD Explain endpoint
    NSString *urlString = [NSString stringWithFormat:@"https://explainxkcd.com/%ld", (long)comicNumber];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (self.connection) {
        self.responseData = [NSMutableData data];
        self.pendingComicNumber = comicNumber;
        self.pendingDelegate = delegate;
        [self.connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.connection start];
    }
}

- (Explanation *)cachedExplanationForComic:(NSInteger)comicNumber {
    return [[ExplanationCache sharedCache] cachedExplanationForComic:comicNumber];
}

- (void)cacheExplanation:(Explanation *)explanation {
    [[ExplanationCache sharedCache] cacheExplanation:explanation];
}

- (void)cacheExplanationFromString:(NSString *)body forComic:(NSInteger)comicNumber {
    Explanation *exp = [[Explanation alloc] init];
    exp.comicNumber = comicNumber;
    exp.body = body ? body : @"No explanation available.";
    exp.references = [NSArray array];
    exp.author = @"Unknown";
    exp.lastUpdated = [NSDate date];
    [[ExplanationCache sharedCache] cacheExplanation:exp];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSError *parseError = nil;
    Explanation *exp = [self.parserStrategy parseData:self.responseData forComic:self.pendingComicNumber error:&parseError];
    [[ExplanationCache sharedCache] cacheExplanation:exp];
    if ([self.pendingDelegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
        [self.pendingDelegate provider:self didFetchExplanation:exp error:parseError];
    }
    self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    Explanation *cached = [[ExplanationCache sharedCache] cachedExplanationForComic:self.pendingComicNumber];
    if ([self.pendingDelegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
        [self.pendingDelegate provider:self didFetchExplanation:cached error:error];
    }
    self.connection = nil;
}

@end

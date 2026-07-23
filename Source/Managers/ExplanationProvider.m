#import "ExplanationProvider.h"
#import "ExplanationCache.h"
#import "Models/Explanation.h"

@interface ExplanationParserStrategy : NSObject
- (Explanation *)parseData:(NSData *)data forComic:(NSInteger)comicNumber error:(NSError **)error;
@end

@implementation ExplanationParserStrategy

#pragma mark - Wikitext Section Extraction

- (NSString *)extractSection:(NSString *)sectionName fromWikitext:(NSString *)wikitext {
    if (!wikitext || !sectionName) return nil;
    // Build patterns for ==Section== variations
    // Try exact case-insensitive
    NSString *pattern1 = [NSString stringWithFormat:@"==%@==", sectionName];
    NSString *pattern2 = [NSString stringWithFormat:@"== %@ ==", sectionName];
    NSRange range = [wikitext rangeOfString:pattern1 options:NSCaseInsensitiveSearch];
    if (range.location == NSNotFound) {
        range = [wikitext rangeOfString:pattern2 options:NSCaseInsensitiveSearch];
    }
    if (range.location == NSNotFound) {
        // Try with lower case and find line containing section name between ==
        // Search for \n==.*section.*==\n
        NSError *err = nil;
        NSString *regexPattern = [NSString stringWithFormat:@"\\n==[^\\n]*%@[^\\n]*==\\n", sectionName];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern options:NSRegularExpressionCaseInsensitive error:&err];
        if (!err) {
            NSTextCheckingResult *match = [regex firstMatchInString:wikitext options:0 range:NSMakeRange(0, wikitext.length)];
            if (match) {
                range = match.range;
            }
        }
    }
    if (range.location == NSNotFound) return nil;

    NSUInteger start = range.location + range.length;
    if (start >= wikitext.length) return nil;
    NSRange searchRange = NSMakeRange(start, wikitext.length - start);
    // Find next section \n== (any section header)
    NSRange nextSection = [wikitext rangeOfString:@"\n==" options:0 range:searchRange];
    if (nextSection.location != NSNotFound) {
        return [wikitext substringWithRange:NSMakeRange(start, nextSection.location - start)];
    } else {
        return [wikitext substringFromIndex:start];
    }
}

- (NSString *)extractExplanationFromWikitext:(NSString *)wikitext {
    NSString *exp = [self extractSection:@"Explanation" fromWikitext:wikitext];
    if (!exp) {
        // Some pages use lowercase or have no explicit header? Try to return nil
        return nil;
    }
    return exp;
}

- (NSString *)extractTranscriptFromWikitext:(NSString *)wikitext {
    NSString *trans = [self extractSection:@"Transcript" fromWikitext:wikitext];
    if (!trans) {
        // Try alternative: some pages may have transcript in different case
        trans = [self extractSection:@"transcript" fromWikitext:wikitext];
    }
    return trans;
}

- (NSString *)cleanWikitext:(NSString *)wikitext {
    if (!wikitext) return @"";
    NSMutableString *clean = [wikitext mutableCopy];
    [self replaceRegex:@"\\[\\[Category:[^\\]]+\\]\\]" inString:clean withTemplate:@""];
    [self replaceRegex:@"\\[\\[File:[^\\]]+\\]\\]" inString:clean withTemplate:@""];
    [self replaceRegex:@"\\[\\[Image:[^\\]]+\\]\\]" inString:clean withTemplate:@""];
    [self replaceRegex:@"\\[\\[[^\\]|]+\\|([^\\]]+)\\]\\]" inString:clean withTemplate:@"$1"];
    [self replaceRegex:@"\\[\\[([^\\]]+)\\]\\]" inString:clean withTemplate:@"$1"];
    [self replaceRegex:@"\\[https?://[^\\s]+\\s+([^\\]]+)\\]" inString:clean withTemplate:@"$1"];
    [self replaceRegex:@"\\[https?://[^\\]]+\\]" inString:clean withTemplate:@""];

    for (int i = 0; i < 10; i++) {
        NSUInteger beforeLen = clean.length;
        [self replaceRegex:@"\\{\\{[^{}]*\\|([^{}|]+)\\}\\}" inString:clean withTemplate:@"$1"];
        if (clean.length == beforeLen) break;
    }
    for (int i = 0; i < 10; i++) {
        NSUInteger before = clean.length;
        [self replaceRegex:@"\\{\\{[^{}]+\\}\\}" inString:clean withTemplate:@""];
        if (clean.length == before) break;
    }

    [clean replaceOccurrencesOfString:@"'''" withString:@"" options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"''" withString:@"" options:0 range:NSMakeRange(0, clean.length)];

    [self replaceRegex:@"<ref[^>]*>.*?</ref>" inString:clean withTemplate:@"" options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators];
    [self replaceRegex:@"<[^>]+>" inString:clean withTemplate:@""];

    [self replaceRegex:@"__[A-Z]+__" inString:clean withTemplate:@""];

    [self replaceRegex:@"\\n\\*\\s*" inString:clean withTemplate:@"\n- "];
    [self replaceRegex:@"\\n#\\s*" inString:clean withTemplate:@"\n"];
    [self replaceRegex:@"\\n:\\s*" inString:clean withTemplate:@"\n"];
    [self replaceRegex:@"\\n;\\s*" inString:clean withTemplate:@"\n"];

    [clean replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"&nbsp;" withString:@" " options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"&#39;" withString:@"'" options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"&#8211;" withString:@"-" options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"&#8212;" withString:@"-" options:0 range:NSMakeRange(0, clean.length)];

    [self replaceRegex:@"\\n{3,}" inString:clean withTemplate:@"\n\n"];
    NSString *result = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return result;
}

- (NSString *)cleanTranscriptWikitext:(NSString *)wikitext {
    if (!wikitext) return @"";
    // Similar cleaning but preserve line breaks more and remove leading colons/brackets
    NSMutableString *clean = [wikitext mutableCopy];
    // Remove categories etc
    [self replaceRegex:@"\\[\\[Category:[^\\]]+\\]\\]" inString:clean withTemplate:@""];
    // Links: [[...]] -> inner
    [self replaceRegex:@"\\[\\[[^\\]|]+\\|([^\\]]+)\\]\\]" inString:clean withTemplate:@"$1"];
    [self replaceRegex:@"\\[\\[([^\\]]+)\\]\\]" inString:clean withTemplate:@"$1"];
    // Templates removal
    for (int i = 0; i < 10; i++) {
        NSUInteger before = clean.length;
        [self replaceRegex:@"\\{\\{[^{}]*\\|([^{}|]+)\\}\\}" inString:clean withTemplate:@"$1"];
        if (clean.length == before) break;
    }
    for (int i = 0; i < 10; i++) {
        NSUInteger before = clean.length;
        [self replaceRegex:@"\\{\\{[^{}]+\\}\\}" inString:clean withTemplate:@""];
        if (clean.length == before) break;
    }
    [clean replaceOccurrencesOfString:@"'''" withString:@"" options:0 range:NSMakeRange(0, clean.length)];
    [clean replaceOccurrencesOfString:@"''" withString:@"" options:0 range:NSMakeRange(0, clean.length)];
    [self replaceRegex:@"<[^>]+>" inString:clean withTemplate:@""];

    // For transcript, lines often start with : - keep content after :
    // Replace leading : and ; but keep text
    [self replaceRegex:@"\\n:\\s*" inString:clean withTemplate:@"\n"];
    [self replaceRegex:@"\\n;\\s*" inString:clean withTemplate:@"\n"];
    [self replaceRegex:@"\\n\\*\\s*" inString:clean withTemplate:@"\n"];

    [self replaceRegex:@"\\n{3,}" inString:clean withTemplate:@"\n\n"];
    return [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)replaceRegex:(NSString *)pattern inString:(NSMutableString *)str withTemplate:(NSString *)templ {
    [self replaceRegex:pattern inString:str withTemplate:templ options:0];
}

- (void)replaceRegex:(NSString *)pattern inString:(NSMutableString *)str withTemplate:(NSString *)templ options:(NSRegularExpressionOptions)opts {
    NSError *err = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:opts error:&err];
    if (err || !regex) return;
    [regex replaceMatchesInString:str options:0 range:NSMakeRange(0, str.length) withTemplate:templ];
}

#pragma mark - HTML Fallback

- (NSString *)stripHTML:(NSString *)html {
    if (!html) return @"";
    NSMutableString *stripped = [html mutableCopy];
    [self replaceRegex:@"<script[^>]*>.*?</script>" inString:stripped withTemplate:@"" options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators];
    [self replaceRegex:@"<style[^>]*>.*?</style>" inString:stripped withTemplate:@"" options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators];
    [self replaceRegex:@"<[^>]+>" inString:stripped withTemplate:@"" options:NSRegularExpressionCaseInsensitive];
    [stripped replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, stripped.length)];
    [stripped replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, stripped.length)];
    [stripped replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, stripped.length)];
    [stripped replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, stripped.length)];
    [stripped replaceOccurrencesOfString:@"&nbsp;" withString:@" " options:0 range:NSMakeRange(0, stripped.length)];
    [stripped replaceOccurrencesOfString:@"&#39;" withString:@"'" options:0 range:NSMakeRange(0, stripped.length)];
    NSString *result = [stripped stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableString *final = [result mutableCopy];
    [self replaceRegex:@"\\n\\s*\\n" inString:final withTemplate:@"\n\n"];
    [self replaceRegex:@"\\s{2,}" inString:final withTemplate:@" "];
    return [final copy];
}

#pragma mark - Main Parse

- (Explanation *)parseData:(NSData *)data forComic:(NSInteger)comicNumber error:(NSError **)error {
    if (!data || data.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Empty data"}];
        return nil;
    }

    NSError *jsonError = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!jsonError && jsonDict) {
        id bodyField = [jsonDict objectForKey:@"body"];
        if ([bodyField isKindOfClass:[NSString class]] && [(NSString *)bodyField length] > 0) {
            Explanation *exp = [[Explanation alloc] init];
            exp.comicNumber = comicNumber;
            exp.body = bodyField;
            exp.references = [jsonDict objectForKey:@"references"] ?: @[];
            exp.author = [jsonDict objectForKey:@"author"] ?: @"";
            exp.transcript = [jsonDict objectForKey:@"transcript"];
            exp.lastUpdated = [NSDate date];
            if (error) *error = nil;
            return exp;
        }

        NSDictionary *parseDict = [jsonDict objectForKey:@"parse"];
        if ([parseDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *wikitextDict = [parseDict objectForKey:@"wikitext"];
            if ([wikitextDict isKindOfClass:[NSDictionary class]]) {
                NSString *wikitext = [wikitextDict objectForKey:@"*"];
                if ([wikitext isKindOfClass:[NSString class]]) {
                    NSString *expSection = [self extractExplanationFromWikitext:wikitext];
                    NSString *transSection = [self extractTranscriptFromWikitext:wikitext];
                    NSString *cleanBody = nil;
                    NSString *cleanTranscript = nil;
                    if (expSection) {
                        cleanBody = [self cleanWikitext:expSection];
                    }
                    if (transSection) {
                        cleanTranscript = [self cleanTranscriptWikitext:transSection];
                    }
                    if (!cleanBody) {
                        cleanBody = [self cleanWikitext:wikitext];
                    }
                    if (cleanBody && cleanBody.length > 10) {
                        Explanation *exp = [[Explanation alloc] init];
                        exp.comicNumber = comicNumber;
                        exp.body = cleanBody;
                        exp.transcript = cleanTranscript;
                        exp.references = @[];
                        exp.author = @"explainxkcd.com";
                        exp.lastUpdated = [NSDate date];
                        if (error) *error = nil;
                        return exp;
                    }
                }
            }

            NSDictionary *textDict = [parseDict objectForKey:@"text"];
            if ([textDict isKindOfClass:[NSDictionary class]]) {
                NSString *html = [textDict objectForKey:@"*"];
                if ([html isKindOfClass:[NSString class]]) {
                    NSString *stripped = [self stripHTML:html];
                    if (stripped.length > 20) {
                        Explanation *exp = [[Explanation alloc] init];
                        exp.comicNumber = comicNumber;
                        exp.body = stripped;
                        exp.references = @[];
                        exp.author = @"explainxkcd.com";
                        exp.lastUpdated = [NSDate date];
                        if (error) *error = nil;
                        return exp;
                    }
                }
            }
        }
    }

    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!text) text = @"";
    NSString *lowerText = [text lowercaseString];
    NSRange expHeading = [lowerText rangeOfString:@"explanation"];
    if (expHeading.location != NSNotFound) {
        NSUInteger start = expHeading.location + expHeading.length;
        if (start < text.length) {
            NSUInteger len = MIN(8000, text.length - start);
            NSString *snippet = [text substringWithRange:NSMakeRange(start, len)];
            NSString *stripped = [self stripHTML:snippet];
            NSRange nextHeading = [stripped rangeOfString:@"Transcript" options:NSCaseInsensitiveSearch];
            if (nextHeading.location != NSNotFound) {
                stripped = [stripped substringToIndex:nextHeading.location];
            }
            if (stripped.length > 20) {
                Explanation *exp = [[Explanation alloc] init];
                exp.comicNumber = comicNumber;
                exp.body = [stripped stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                exp.references = @[];
                exp.author = @"Unknown";
                exp.lastUpdated = [NSDate date];
                if (error) *error = nil;
                return exp;
            }
        }
    }

    NSString *stripped = [self stripHTML:text];
    if (stripped.length < 20) {
        if (error) *error = [NSError errorWithDomain:@"TouchXKCD" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Explanation content too short or invalid"}];
    } else {
        if (error) *error = nil;
    }
    Explanation *exp = [[Explanation alloc] init];
    exp.comicNumber = comicNumber;
    exp.body = stripped.length > 0 ? stripped : @"No explanation available.";
    exp.references = @[];
    exp.author = @"Unknown";
    exp.lastUpdated = [NSDate date];
    return exp;
}

@end

@interface ExplanationRequestInfo : NSObject
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, assign) id<ExplanationProviderDelegate> delegate;
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation ExplanationRequestInfo
@end

@interface ExplanationProvider () <NSURLConnectionDataDelegate, NSURLConnectionDelegate>
@property (nonatomic, strong) NSMutableDictionary *requests;
@property (nonatomic, strong) ExplanationParserStrategy *parserStrategy;
@end

@implementation ExplanationProvider

+ (instancetype)sharedProvider {
    static ExplanationProvider *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.parserStrategy = [[ExplanationParserStrategy alloc] init];
        shared.requests = [NSMutableDictionary dictionary];
    });
    return shared;
}

- (void)fetchExplanationForComic:(NSInteger)comicNumber delegate:(id<ExplanationProviderDelegate>)delegate {
    if (comicNumber <= 0) {
        if ([delegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
            NSError *err = [NSError errorWithDomain:@"TouchXKCD" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"Invalid comic number"}];
            [delegate provider:self didFetchExplanation:nil error:err];
        }
        return;
    }

    Explanation *cached = [[ExplanationCache sharedCache] cachedExplanationForComic:comicNumber];
    if (cached) {
        if ([delegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
            [delegate provider:self didFetchExplanation:cached error:nil];
        }
    }

    @synchronized(self.requests) {
        for (ExplanationRequestInfo *info in [self.requests allValues]) {
            if (info.comicNumber == comicNumber) {
                info.delegate = delegate;
                return;
            }
        }
    }

    NSString *urlString = [NSString stringWithFormat:@"https://www.explainxkcd.com/wiki/api.php?action=parse&page=%ld&prop=wikitext&format=json&redirects=1", (long)comicNumber];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if ([delegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
            NSError *err = [NSError errorWithDomain:@"TouchXKCD" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid explanation URL"}];
            [delegate provider:self didFetchExplanation:cached error:err];
        }
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setValue:@"TouchXKCD/1.0 (iPod touch; iOS 6.1.6)" forHTTPHeaderField:@"User-Agent"];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    if (connection) {
        ExplanationRequestInfo *info = [[ExplanationRequestInfo alloc] init];
        info.responseData = [NSMutableData data];
        info.comicNumber = comicNumber;
        info.delegate = delegate;
        info.connection = connection;
        @synchronized(self.requests) {
            [self.requests setObject:info forKey:[NSValue valueWithNonretainedObject:connection]];
        }
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [connection start];
    } else {
        if ([delegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
            NSError *err = [NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create connection"}];
            [delegate provider:self didFetchExplanation:cached error:err];
        }
    }
}

- (Explanation *)cachedExplanationForComic:(NSInteger)comicNumber {
    return [[ExplanationCache sharedCache] cachedExplanationForComic:comicNumber];
}
- (void)cacheExplanation:(Explanation *)explanation {
    [[ExplanationCache sharedCache] cacheExplanation:explanation];
}
- (void)cacheExplanationFromString:(NSString *)body forComic:(NSInteger)comicNumber {
    if (comicNumber <= 0) return;
    Explanation *exp = [[Explanation alloc] init];
    exp.comicNumber = comicNumber;
    exp.body = body ? body : @"No explanation available.";
    exp.references = @[];
    exp.author = @"Unknown";
    exp.lastUpdated = [NSDate date];
    [[ExplanationCache sharedCache] cacheExplanation:exp];
}

- (ExplanationRequestInfo *)infoForConnection:(NSURLConnection *)connection {
    @synchronized(self.requests) {
        return [self.requests objectForKey:[NSValue valueWithNonretainedObject:connection]];
    }
}
- (void)removeInfoForConnection:(NSURLConnection *)connection {
    @synchronized(self.requests) {
        [self.requests removeObjectForKey:[NSValue valueWithNonretainedObject:connection]];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    ExplanationRequestInfo *info = [self infoForConnection:connection];
    [info.responseData setLength:0];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    ExplanationRequestInfo *info = [self infoForConnection:connection];
    [info.responseData appendData:data];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    ExplanationRequestInfo *info = [self infoForConnection:connection];
    [self removeInfoForConnection:connection];
    if (!info) return;
    NSError *parseError = nil;
    Explanation *exp = [self.parserStrategy parseData:info.responseData forComic:info.comicNumber error:&parseError];
    if (exp && exp.body.length > 10) {
        [[ExplanationCache sharedCache] cacheExplanation:exp];
    }
    id<ExplanationProviderDelegate> delegate = info.delegate;
    if ([delegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
        if (!exp) {
            exp = [[ExplanationCache sharedCache] cachedExplanationForComic:info.comicNumber];
        }
        [delegate provider:self didFetchExplanation:exp error:parseError];
    }
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    ExplanationRequestInfo *info = [self infoForConnection:connection];
    [self removeInfoForConnection:connection];
    if (!info) return;
    Explanation *cached = [[ExplanationCache sharedCache] cachedExplanationForComic:info.comicNumber];
    id<ExplanationProviderDelegate> delegate = info.delegate;
    if ([delegate respondsToSelector:@selector(provider:didFetchExplanation:error:)]) {
        [delegate provider:self didFetchExplanation:cached error:error];
    }
}

@end

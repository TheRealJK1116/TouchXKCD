#import "Comic.h"

@implementation Comic

+ (instancetype)comicWithNumber:(NSInteger)number {
    Comic *comic = [[self alloc] init];
    comic.number = number;
    return comic;
}

- (BOOL)isCached {
    if (self.number <= 0) return NO;
    NSString *path = [self cachedImagePath];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSString *)cachedImagePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [paths objectAtIndex:0];
    NSString *imageDir = [cacheDir stringByAppendingPathComponent:@"TouchXKCD/images"];
    // Try to preserve extension from imageURL
    NSString *ext = @"jpg";
    if (self.imageURL) {
        NSString *urlExt = [[self.imageURL lastPathComponent] pathExtension];
        if (urlExt && urlExt.length > 0) ext = urlExt;
    }
    return [imageDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.%@", (long)self.number, ext]];
}

- (void)hydrateFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary || ![dictionary isKindOfClass:[NSDictionary class]]) return;

    id numObj = [dictionary objectForKey:@"num"];
    if ([numObj respondsToSelector:@selector(integerValue)]) {
        self.number = [numObj integerValue];
    }

    id titleObj = [dictionary objectForKey:@"title"];
    self.title = ([titleObj isKindOfClass:[NSString class]] && [(NSString *)titleObj length] > 0) ? titleObj : @"Untitled";

    id imgObj = [dictionary objectForKey:@"img"];
    self.imageURL = [imgObj isKindOfClass:[NSString class]] ? imgObj : @"";

    id altObj = [dictionary objectForKey:@"alt"];
    self.altText = [altObj isKindOfClass:[NSString class]] ? altObj : @"";

    id transcriptObj = [dictionary objectForKey:@"transcript"];
    NSString *rawTranscript = [transcriptObj isKindOfClass:[NSString class]] ? transcriptObj : @"";
    // Clean transcript: remove wiki markup like [[...]] and {{Alt: ...}}
    if (rawTranscript.length > 0) {
        NSString *cleaned = rawTranscript;
        // Remove {{Alt: ...}} etc
        NSRegularExpression *altRegex = [NSRegularExpression regularExpressionWithPattern:@"\\{\\{Alt:[^\\}]*\\}\\}" options:NSRegularExpressionCaseInsensitive error:nil];
        cleaned = [altRegex stringByReplacingMatchesInString:cleaned options:0 range:NSMakeRange(0, cleaned.length) withTemplate:@""];
        // [[...]] -> inner text, but [[A boy sits...]] is description, keep inner
        NSRegularExpression *linkDisplayRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\[([^\\]|]+)\\|([^\\]]+)\\]\\]" options:0 error:nil];
        cleaned = [linkDisplayRegex stringByReplacingMatchesInString:cleaned options:0 range:NSMakeRange(0, cleaned.length) withTemplate:@"$2"];
        NSRegularExpression *linkRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\[([^\\]]+)\\]\\]" options:0 error:nil];
        cleaned = [linkRegex stringByReplacingMatchesInString:cleaned options:0 range:NSMakeRange(0, cleaned.length) withTemplate:@"$1"];
        // Trim
        cleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        self.transcript = cleaned;
    } else {
        self.transcript = @"";
    }

    id linkObj = [dictionary objectForKey:@"link"];
    self.linkURL = [linkObj isKindOfClass:[NSString class]] ? linkObj : @"";

    // Build date from year/month/day fields in JSON (they may be strings or numbers)
    id monthObj = [dictionary objectForKey:@"month"];
    id dayObj = [dictionary objectForKey:@"day"];
    id yearObj = [dictionary objectForKey:@"year"];
    if (monthObj && dayObj && yearObj) {
        NSInteger month = [monthObj integerValue];
        NSInteger day = [dayObj integerValue];
        NSInteger year = [yearObj integerValue];
        if (year > 0 && month > 0 && day > 0) {
            NSString *dateStr = [NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)year, (long)month, (long)day];
            self.dateString = dateStr;
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd"];
            [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
            self.parsedDate = [formatter dateFromString:dateStr];
        } else {
            self.dateString = @"Unknown";
        }
    } else {
        self.dateString = @"Unknown";
    }

    // Explanation body if present in dict (denormalized)
    id explObj = [dictionary objectForKey:@"explanation"];
    if ([explObj isKindOfClass:[NSString class]]) {
        self.explanationBody = explObj;
    }
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.number forKey:@"number"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.imageURL forKey:@"imageURL"];
    [coder encodeObject:self.altText forKey:@"altText"];
    [coder encodeObject:self.transcript forKey:@"transcript"];
    [coder encodeObject:self.linkURL forKey:@"linkURL"];
    [coder encodeObject:self.dateString forKey:@"dateString"];
    [coder encodeObject:self.parsedDate forKey:@"parsedDate"];
    [coder encodeObject:self.explanationBody forKey:@"explanationBody"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.number = [coder decodeIntegerForKey:@"number"];
        self.title = [coder decodeObjectForKey:@"title"];
        self.imageURL = [coder decodeObjectForKey:@"imageURL"];
        self.altText = [coder decodeObjectForKey:@"altText"];
        self.transcript = [coder decodeObjectForKey:@"transcript"];
        self.linkURL = [coder decodeObjectForKey:@"linkURL"];
        self.dateString = [coder decodeObjectForKey:@"dateString"];
        self.parsedDate = [coder decodeObjectForKey:@"parsedDate"];
        self.explanationBody = [coder decodeObjectForKey:@"explanationBody"];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<Comic #%ld: %@>", (long)self.number, self.title];
}

@end

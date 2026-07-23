#import "Explanation.h"

@implementation Explanation

+ (instancetype)explanationForComic:(NSInteger)comicNumber {
    if (comicNumber <= 0) return nil;
    Explanation *exp = [[self alloc] init];
    exp.comicNumber = comicNumber;
    exp.lastUpdated = [NSDate date];
    return exp;
}

- (NSString *)formattedBody {
    if (self.body && self.body.length > 0) {
        // Ensure body is trimmed and has some formatting
        NSString *trimmed = [self.body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) return trimmed;
    }
    return @"No explanation available.";
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<Explanation #%ld: %lu chars>", (long)self.comicNumber, (unsigned long)[self.body length]];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.comicNumber forKey:@"comicNumber"];
    [coder encodeObject:self.body forKey:@"body"];
    [coder encodeObject:self.references forKey:@"references"];
    [coder encodeObject:self.author forKey:@"author"];
    [coder encodeObject:self.lastUpdated forKey:@"lastUpdated"];
    [coder encodeObject:self.transcript forKey:@"transcript"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.comicNumber = [coder decodeIntegerForKey:@"comicNumber"];
        self.body = [coder decodeObjectForKey:@"body"];
        self.references = [coder decodeObjectForKey:@"references"];
        if (!self.references) self.references = [NSArray array];
        self.author = [coder decodeObjectForKey:@"author"];
        self.lastUpdated = [coder decodeObjectForKey:@"lastUpdated"];
        if (!self.lastUpdated) self.lastUpdated = [NSDate date];
        self.transcript = [coder decodeObjectForKey:@"transcript"];
    }
    return self;
}

@end

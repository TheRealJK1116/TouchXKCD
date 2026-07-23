#import "Explanation.h"

@implementation Explanation

+ (instancetype)explanationForComic:(NSInteger)comicNumber {
    Explanation *exp = [[self alloc] init];
    exp.comicNumber = comicNumber;
    return exp;
}

- (NSString *)formattedBody {
    return self.body ? self.body : @"No explanation available.";
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.comicNumber forKey:@"comicNumber"];
    [coder encodeObject:self.body forKey:@"body"];
    [coder encodeObject:self.references forKey:@"references"];
    [coder encodeObject:self.author forKey:@"author"];
    [coder encodeObject:self.lastUpdated forKey:@"lastUpdated"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.comicNumber = [coder decodeIntegerForKey:@"comicNumber"];
        self.body = [coder decodeObjectForKey:@"body"];
        self.references = [coder decodeObjectForKey:@"references"];
        self.author = [coder decodeObjectForKey:@"author"];
        self.lastUpdated = [coder decodeObjectForKey:@"lastUpdated"];
    }
    return self;
}

@end

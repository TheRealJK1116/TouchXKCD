#import "Comic.h"

@implementation Comic

+ (instancetype)comicWithNumber:(NSInteger)number {
    Comic *comic = [[self alloc] init];
    comic.number = number;
    return comic;
}

- (BOOL)isCached {
    NSString *path = [self cachedImagePath];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSString *)cachedImagePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [paths objectAtIndex:0];
    NSString *imageDir = [cacheDir stringByAppendingPathComponent:@"TouchXKCD/images"];
    return [imageDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.jpg", (long)self.number]];
}

- (void)hydrateFromDictionary:(NSDictionary *)dictionary {
    self.number = [[dictionary objectForKey:@"num"] intValue];
    self.title = [dictionary objectForKey:@"title"] ? [dictionary objectForKey:@"title"] : @"Untitled";
    self.imageURL = [dictionary objectForKey:@"img"] ? [dictionary objectForKey:@"img"] : @"";
    self.altText = [dictionary objectForKey:@"alt"] ? [dictionary objectForKey:@"alt"] : @"";
    self.transcript = [dictionary objectForKey:@"transcript"] ? [dictionary objectForKey:@"transcript"] : @"";
    self.linkURL = [dictionary objectForKey:@"link"] ? [dictionary objectForKey:@"link"] : @"";

    // Build date from year/month/day fields in JSON
    NSString *month = [dictionary objectForKey:@"month"];
    NSString *day = [dictionary objectForKey:@"day"];
    NSString *year = [dictionary objectForKey:@"year"];
    if (month && day && year) {
        NSString *dateStr = [NSString stringWithFormat:@"%04ld-%04ld-%04ld", (long)[year intValue], (long)[month intValue], (long)[day intValue]];
        self.dateString = dateStr;
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd"];
        self.parsedDate = [formatter dateFromString:dateStr];
    } else {
        self.dateString = @"Unknown";
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
        self.explanationBody = [coder decodeObjectForKey:@"explanationBody"];
    }
    return self;
}

@end

#import "ComicParser.h"
#import "Models/Comic.h"

@implementation ComicParser

+ (Comic *)parseComicFromData:(NSData *)data error:(NSError **)error {
    NSError *parseError = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (parseError) {
        if (error) *error = parseError;
        return nil;
    }
    return [self parseComicFromDictionary:dict];
}

+ (Comic *)parseComicFromDictionary:(NSDictionary *)dictionary {
    Comic *comic = [[Comic alloc] init];
    [comic hydrateFromDictionary:dictionary];
    return comic;
}

@end

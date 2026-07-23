#import "ComicParser.h"
#import "Models/Comic.h"

@implementation ComicParser

+ (Comic *)parseComicFromData:(NSData *)data error:(NSError **)error {
    if (!data || data.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TouchXKCD" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Empty data"}];
        }
        return nil;
    }
    NSError *parseError = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (parseError) {
        if (error) *error = parseError;
        return nil;
    }
    if (![dict isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TouchXKCD" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"JSON root is not a dictionary"}];
        }
        return nil;
    }
    return [self parseComicFromDictionary:dict];
}

+ (Comic *)parseComicFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary || ![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    Comic *comic = [[Comic alloc] init];
    @try {
        [comic hydrateFromDictionary:dictionary];
    } @catch (NSException *ex) {
        NSLog(@"[ComicParser] Hydration exception: %@", ex);
        return nil;
    }
    // Validate essential fields
    if (comic.number <= 0) return nil;
    if (!comic.title) comic.title = @"Untitled";
    return comic;
}

@end

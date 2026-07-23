#import <Foundation/Foundation.h>

@class Comic;

@interface ComicParser : NSObject

+ (Comic *)parseComicFromData:(NSData *)data error:(NSError **)error;
+ (Comic *)parseComicFromDictionary:(NSDictionary *)dictionary;

@end

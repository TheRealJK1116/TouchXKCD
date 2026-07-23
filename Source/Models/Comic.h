#import <Foundation/Foundation.h>

@interface Comic : NSObject <NSCoding>

@property (nonatomic, assign) NSInteger number;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *imageURL;
@property (nonatomic, strong) NSString *altText;
@property (nonatomic, strong) NSString *transcript;
@property (nonatomic, strong) NSString *linkURL;
@property (nonatomic, strong) NSString *dateString;
@property (nonatomic, strong) NSDate *parsedDate;
@property (nonatomic, strong) NSString *explanationBody;

+ (instancetype)comicWithNumber:(NSInteger)number;
- (BOOL)isCached;
- (NSString *)cachedImagePath;
- (void)hydrateFromDictionary:(NSDictionary *)dictionary;

@end

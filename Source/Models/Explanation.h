#import <Foundation/Foundation.h>

@interface Explanation : NSObject <NSCoding>

@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSArray *references;
@property (nonatomic, strong) NSString *author;
@property (nonatomic, strong) NSDate *lastUpdated;

+ (instancetype)explanationForComic:(NSInteger)comicNumber;
- (NSString *)formattedBody;

@end

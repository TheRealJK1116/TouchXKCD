#import <Foundation/Foundation.h>

@interface Favourite : NSObject <NSCoding>

@property (nonatomic, assign) NSInteger comicNumber;
@property (nonatomic, strong) NSDate *addedAt;
@property (nonatomic, strong) NSString *note;

+ (NSArray *)allFavourites;
+ (BOOL)isFavourite:(NSInteger)comicNumber;
- (void)add;
- (void)remove;

@end

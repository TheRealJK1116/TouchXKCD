#import <Foundation/Foundation.h>

@interface ImageCache : NSObject

+ (instancetype)sharedCache;
- (UIImage *)cachedImageForKey:(NSString *)key;
- (void)cacheImage:(UIImage *)image forKey:(NSString *)key;
- (void)clearCache;

@end

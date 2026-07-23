#import "ImageCache.h"

@interface ImageCache ()
@property (nonatomic, strong) NSCache *cache;
@end

@implementation ImageCache

+ (instancetype)sharedCache {
    static ImageCache *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.cache = [[NSCache alloc] init];
        [shared.cache setName:@"TouchXKCDImageCache"];
        [shared.cache setCountLimit:30];
    });
    return shared;
}

- (UIImage *)cachedImageForKey:(NSString *)key {
    return [self.cache objectForKey:key];
}

- (void)cacheImage:(UIImage *)image forKey:(NSString *)key {
    if (image) {
        [self.cache setObject:image forKey:key];
    }
}

- (void)clearCache {
    [self.cache removeAllObjects];
}

- (void)pruneCacheToLimit:(NSInteger)limit {
    // NSCache automatically handles count limits; this is a placeholder for future LRU-based file pruning.
}

- (void)dealloc {
    // ARC handles; no explicit release needed.
}

@end

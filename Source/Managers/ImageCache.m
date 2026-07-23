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
        [shared.cache setTotalCostLimit:10 * 1024 * 1024]; // 10MB per ARCHITECTURE.md
        // Observe memory warnings
        [[NSNotificationCenter defaultCenter] addObserver:shared selector:@selector(handleMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    });
    return shared;
}

- (void)handleMemoryWarning {
    [self clearCache];
}

- (UIImage *)cachedImageForKey:(NSString *)key {
    if (!key) return nil;
    return [self.cache objectForKey:key];
}

- (void)cacheImage:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) return;
    // Estimate cost: width * height * 4 bytes
    NSUInteger cost = (NSUInteger)(image.size.width * image.size.height * 4);
    if (cost == 0) cost = 1;
    [self.cache setObject:image forKey:key cost:cost];
}

- (void)clearCache {
    [self.cache removeAllObjects];
}

- (void)pruneCacheToLimit:(NSInteger)limit {
    if (limit > 0) {
        [self.cache setCountLimit:limit];
    }
    // NSCache auto-evicts; for file cache, caller should handle LRU pruning separately
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

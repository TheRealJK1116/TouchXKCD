#import "ExplanationCache.h"
#import "Models/Explanation.h"

@interface ExplanationCache ()
@property (nonatomic, strong) NSString *cacheDir;
@end

@implementation ExplanationCache

+ (instancetype)sharedCache {
    static ExplanationCache *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *dir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/explanations"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        self.cacheDir = dir;
    }
    return self;
}

- (NSString *)cachePathForComic:(NSInteger)comicNumber {
    return [self.cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"explanation_%ld.archive", (long)comicNumber]];
}

- (Explanation *)cachedExplanationForComic:(NSInteger)comicNumber {
    NSString *path = [self cachePathForComic:comicNumber];
    Explanation *exp = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    return exp;
}

- (void)cacheExplanation:(Explanation *)explanation {
    if (!explanation) return;
    NSString *path = [self cachePathForComic:explanation.comicNumber];
    [NSKeyedArchiver archiveRootObject:explanation toFile:path];
}

- (void)clearCache {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:self.cacheDir error:nil];
    for (NSString *file in files) {
        [fm removeItemAtPath:[self.cacheDir stringByAppendingPathComponent:file] error:nil];
    }
}

@end

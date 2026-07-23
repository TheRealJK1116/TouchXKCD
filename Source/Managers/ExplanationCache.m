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
        NSString *base = [paths objectAtIndex:0];
        NSString *dir = [base stringByAppendingPathComponent:@"TouchXKCD/explanations"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:dir]) {
            NSError *err = nil;
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&err];
            if (err) NSLog(@"[ExplanationCache] Failed to create dir %@: %@", dir, err);
        }
        self.cacheDir = dir;
    }
    return self;
}

- (NSString *)cachePathForComic:(NSInteger)comicNumber {
    if (comicNumber <= 0) return nil;
    return [self.cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"explanation_%ld.archive", (long)comicNumber]];
}

- (Explanation *)cachedExplanationForComic:(NSInteger)comicNumber {
    if (comicNumber <= 0) return nil;
    NSString *path = [self cachePathForComic:comicNumber];
    if (!path) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    @try {
        Explanation *exp = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        return exp;
    } @catch (NSException *ex) {
        NSLog(@"[ExplanationCache] Unarchive failed for #%ld: %@", (long)comicNumber, ex);
        return nil;
    }
}

- (void)cacheExplanation:(Explanation *)explanation {
    if (!explanation || explanation.comicNumber <= 0) return;
    NSString *path = [self cachePathForComic:explanation.comicNumber];
    if (!path) return;
    @try {
        BOOL ok = [NSKeyedArchiver archiveRootObject:explanation toFile:path];
        if (!ok) NSLog(@"[ExplanationCache] Failed to archive #%ld", (long)explanation.comicNumber);
    } @catch (NSException *ex) {
        NSLog(@"[ExplanationCache] Archive exception #%ld: %@", (long)explanation.comicNumber, ex);
    }
}

- (void)clearCache {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSArray *files = [fm contentsOfDirectoryAtPath:self.cacheDir error:&err];
    if (err) {
        NSLog(@"[ExplanationCache] List error: %@", err);
        return;
    }
    NSInteger removed = 0;
    for (NSString *file in files) {
        NSString *full = [self.cacheDir stringByAppendingPathComponent:file];
        if ([fm removeItemAtPath:full error:nil]) removed++;
    }
    NSLog(@"[ExplanationCache] Cleared %ld files", (long)removed);
}

- (NSUInteger)cacheCount {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cacheDir error:nil];
    return [files count];
}

@end

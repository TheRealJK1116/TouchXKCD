#import "StorageManager.h"
#import "Models/Comic.h"
#import "Managers/DownloadTask.h"

@implementation StorageManager

+ (instancetype)sharedManager {
    static StorageManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (NSString *)databaseDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths objectAtIndex:0];
    NSString *appDir = [dir stringByAppendingPathComponent:@"TouchXKCD"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:appDir]) {
        [fm createDirectoryAtPath:appDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return appDir;
}

- (NSString *)comicFilePath:(NSInteger)number {
    return [[self databaseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"comic_%ld.archive", (long)number]];
}

- (BOOL)initializeDatabase {
    // File-based archive persistence; ensure directory exists.
    [self databaseDirectory];
    return YES;
}

- (void)vacuumIfNeeded {
    // Not applicable for file-based archive, but could prune old files if over limit.
    // Placeholder for future LRU pruning based on Settings maxCacheSize.
}

- (void)saveComic:(Comic *)comic {
    if (!comic || comic.number <= 0) return;
    NSString *path = [self comicFilePath:comic.number];
    BOOL success = [NSKeyedArchiver archiveRootObject:comic toFile:path];
    if (!success) {
        NSLog(@"[StorageManager] Failed to archive comic #%ld to %@", (long)comic.number, path);
    }
}

- (Comic *)loadComic:(NSInteger)number {
    if (number <= 0) return nil;
    NSString *path = [self comicFilePath:number];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        return nil;
    }
    @try {
        Comic *comic = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if (comic && comic.number == 0) {
            comic.number = number;
        }
        return comic;
    } @catch (NSException *ex) {
        NSLog(@"[StorageManager] Exception unarchiving comic #%ld: %@", (long)number, ex);
        return nil;
    }
}

- (NSArray *)loadAllComics {
    NSString *dir = [self databaseDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
    NSMutableArray *comics = [NSMutableArray array];
    if (!files) return comics;
    for (NSString *file in files) {
        if ([file hasPrefix:@"comic_"] && [file hasSuffix:@".archive"]) {
            if (file.length <= 14) continue;
            NSRange numRange = NSMakeRange(6, file.length - 14);
            if (numRange.location + numRange.length > file.length) continue;
            NSString *numStr = [file substringWithRange:numRange];
            NSInteger number = [numStr integerValue];
            if (number <= 0) continue;
            Comic *comic = [self loadComic:number];
            if (comic) {
                [comics addObject:comic];
            }
        }
    }
    return [comics copy];
}

- (void)deleteComic:(NSInteger)number {
    if (number <= 0) return;
    NSString *path = [self comicFilePath:number];
    NSError *err = nil;
    BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:path error:&err];
    if (!removed && err) {
        NSLog(@"[StorageManager] Failed to delete comic #%ld: %@", (long)number, err);
    }
}

- (void)saveDownloadTask:(DownloadTask *)task {
    // Persistence handled by DownloadManager; placeholder for SQLite integration.
}

- (DownloadTask *)loadDownloadTask:(NSInteger)taskID {
    // SQLite integration point
    return nil;
}

- (NSArray *)loadAllDownloadTasks {
    return [NSArray array];
}

@end

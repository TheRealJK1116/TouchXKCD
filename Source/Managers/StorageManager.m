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
    // File-based archive persistence for skeleton.
    return YES;
}

- (void)vacuumIfNeeded {
    // Not applicable for file-based archive.
}

- (void)saveComic:(Comic *)comic {
    NSString *path = [self comicFilePath:comic.number];
    [NSKeyedArchiver archiveRootObject:comic toFile:path];
}

- (Comic *)loadComic:(NSInteger)number {
    NSString *path = [self comicFilePath:number];
    Comic *comic = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    if (comic) {
        comic.number = number;
    } else {
        comic = [Comic comicWithNumber:number];
    }
    return comic;
}

- (NSArray *)loadAllComics {
    NSString *dir = [self databaseDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
    NSMutableArray *comics = [NSMutableArray array];
    for (NSString *file in files) {
        if ([file hasPrefix:@"comic_"] && [file hasSuffix:@".archive"]) {
            NSString *numStr = [file substringWithRange:NSMakeRange(6, file.length - 6 - 8)];
            NSInteger number = [numStr intValue];
            Comic *comic = [self loadComic:number];
            if (comic) {
                [comics addObject:comic];
            }
        }
    }
    return comics;
}

- (void)deleteComic:(NSInteger)number {
    NSString *path = [self comicFilePath:number];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (void)saveDownloadTask:(DownloadTask *)task {
    // Persistence handled by DownloadManager; this is a placeholder for SQLite integration.
}

- (DownloadTask *)loadDownloadTask:(NSInteger)taskID {
    // SQLite integration point
    return nil;
}

- (NSArray *)loadAllDownloadTasks {
    // Return download tasks from persistence
    return [NSArray array];
}

@end

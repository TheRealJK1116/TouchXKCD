#import "Favourite.h"

@interface Favourite ()
+ (NSString *)favouritesFilePath;
@end

@implementation Favourite

+ (NSString *)favouritesFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/favourites"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [dir stringByAppendingPathComponent:@"favourites.archive"];
}

+ (NSArray *)allFavourites {
    NSArray *favList = [NSKeyedUnarchiver unarchiveObjectWithFile:[self favouritesFilePath]];
    return favList ? favList : [NSArray array];
}

+ (BOOL)isFavourite:(NSInteger)comicNumber {
    NSArray *favs = [self allFavourites];
    for (Favourite *fav in favs) {
        if (fav.comicNumber == comicNumber) {
            return YES;
        }
    }
    return NO;
}

- (void)add {
    if ([[self class] isFavourite:self.comicNumber]) {
        return; // Prevent duplicates
    }
    self.addedAt = [NSDate date];
    NSMutableArray *favs = [[Favourite allFavourites] mutableCopy];
    if (!favs) favs = [NSMutableArray array];
    [favs addObject:self];
    [NSKeyedArchiver archiveRootObject:favs toFile:[[self class] favouritesFilePath]];
}

- (void)remove {
    NSArray *currentFavs = [Favourite allFavourites];
    NSMutableArray *favs = [currentFavs mutableCopy];
    if (!favs) favs = [NSMutableArray array];
    NSMutableArray *toRemove = [NSMutableArray array];
    for (Favourite *fav in currentFavs) {
        if (fav.comicNumber == self.comicNumber) {
            [toRemove addObject:fav];
        }
    }
    [favs removeObjectsInArray:toRemove];
    [NSKeyedArchiver archiveRootObject:favs toFile:[[self class] favouritesFilePath]];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.comicNumber forKey:@"comicNumber"];
    [coder encodeObject:self.addedAt forKey:@"addedAt"];
    [coder encodeObject:self.note forKey:@"note"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.comicNumber = [coder decodeIntegerForKey:@"comicNumber"];
        self.addedAt = [coder decodeObjectForKey:@"addedAt"];
        self.note = [coder decodeObjectForKey:@"note"];
    }
    return self;
}

@end

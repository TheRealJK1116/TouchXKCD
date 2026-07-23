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
    self.addedAt = [NSDate date];
    NSMutableArray *favs = [[Favourite allFavourites] mutableCopy];
    [favs addObject:self];
    [NSKeyedArchiver archiveRootObject:favs toFile:[[self class] favouritesFilePath]];
}

- (void)remove {
    NSMutableArray *favs = [[Favourite allFavourites] mutableCopy];
    for (Favourite *fav in favs) {
        if (fav.comicNumber == self.comicNumber) {
            [favs removeObject:fav];
            break;
        }
    }
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

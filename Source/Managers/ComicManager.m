#import "ComicManager.h"
#import "Managers/XKCDNetworkClient.h"
#import "Managers/StorageManager.h"
#import "Managers/ImageCache.h"
#import "Managers/ImageDownloader.h"
#import "Managers/SearchManager.h"
#import "Managers/SettingsManager.h"
#import "Models/Comic.h"

@interface ComicManager ()
@property (nonatomic, strong) Comic *latestComic;
@property (nonatomic, strong) Comic *currentComic;
@property (nonatomic, strong) NSMutableDictionary *pendingDelegates;
@property (nonatomic, assign) NSInteger knownMaxComicNumber;
@end

@implementation ComicManager

+ (instancetype)sharedManager {
    static ComicManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.pendingDelegates = [NSMutableDictionary dictionary];
        shared.knownMaxComicNumber = 0;
    });
    return shared;
}

- (void)fetchComic:(NSInteger)number delegate:(id<ComicNetworkDelegate>)delegate {
    if (number <= 0) {
        [self fetchLatestComic:delegate];
        return;
    }
    if (delegate) {
        @synchronized(self.pendingDelegates) {
            [self.pendingDelegates setObject:delegate forKey:@(number)];
        }
    }

    // Offline-only check
    Settings *settings = [[SettingsManager sharedInstance] currentSettings];
    Comic *cached = [[StorageManager sharedManager] loadComic:number];

    if (settings.offlineOnly) {
        if (cached) {
            if (delegate && [delegate respondsToSelector:@selector(comicFetched:)]) {
                [delegate comicFetched:cached];
            }
            @synchronized(self.pendingDelegates) {
                [self.pendingDelegates removeObjectForKey:@(number)];
            }
        } else {
            if (delegate && [delegate respondsToSelector:@selector(comicFetchFailed:error:)]) {
                NSError *err = [NSError errorWithDomain:@"TouchXKCD" code:-1009 userInfo:@{NSLocalizedDescriptionKey: @"Offline mode enabled, comic not cached"}];
                [delegate comicFetchFailed:number error:err];
            }
            @synchronized(self.pendingDelegates) {
                [self.pendingDelegates removeObjectForKey:@(number)];
            }
        }
        return;
    }

    // Offline-first: return cached immediately if available
    if (cached) {
        if (delegate && [delegate respondsToSelector:@selector(comicFetched:)]) {
            [delegate comicFetched:cached];
        }
        // Also refresh in background, but keep delegate for update
    }

    [[XKCDNetworkClient sharedClient] fetchComicWithNumber:number delegate:self];
}

- (void)fetchLatestComic:(id<ComicNetworkDelegate>)delegate {
    if (delegate) {
        @synchronized(self.pendingDelegates) {
            [self.pendingDelegates setObject:delegate forKey:@(0)];
        }
    }

    Settings *settings = [[SettingsManager sharedInstance] currentSettings];
    if (settings.offlineOnly) {
        // Try to return highest cached comic as latest approximation
        NSArray *all = [[StorageManager sharedManager] loadAllComics];
        Comic *maxComic = nil;
        for (Comic *c in all) {
            if (!maxComic || c.number > maxComic.number) {
                maxComic = c;
            }
        }
        if (maxComic) {
            if (delegate && [delegate respondsToSelector:@selector(comicFetched:)]) {
                [delegate comicFetched:maxComic];
            }
        } else {
            if (delegate && [delegate respondsToSelector:@selector(comicFetchFailed:error:)]) {
                NSError *err = [NSError errorWithDomain:@"TouchXKCD" code:-1009 userInfo:@{NSLocalizedDescriptionKey: @"Offline mode, no cached comics"}];
                [delegate comicFetchFailed:0 error:err];
            }
        }
        @synchronized(self.pendingDelegates) {
            [self.pendingDelegates removeObjectForKey:@(0)];
        }
        return;
    }

    [[XKCDNetworkClient sharedClient] fetchLatestComicWithDelegate:self];
}

- (void)fetchRandomComic:(id<ComicNetworkDelegate>)delegate {
    NSInteger maxNumber = self.knownMaxComicNumber;
    if (maxNumber <= 0) {
        if (self.latestComic) {
            maxNumber = self.latestComic.number;
        } else {
            // Fallback to known archive size ~3000, but use 2500 for safety as before
            // Try to infer from cached comics
            NSArray *all = [[StorageManager sharedManager] loadAllComics];
            for (Comic *c in all) {
                if (c.number > maxNumber) maxNumber = c.number;
            }
            if (maxNumber <= 0) maxNumber = 2500;
        }
    }
    NSInteger randomNumber = (arc4random_uniform((u_int32_t)maxNumber) + 1);
    if (randomNumber < 1) randomNumber = 1;
    if (delegate) {
        @synchronized(self.pendingDelegates) {
            // Store under random number and also under 0 for latest fallback
            [self.pendingDelegates setObject:delegate forKey:@(randomNumber)];
        }
    }
    [self fetchComic:randomNumber delegate:delegate];
}

- (void)fetchPreviousComic:(NSInteger)currentNumber delegate:(id<ComicNetworkDelegate>)delegate {
    NSInteger prev = (currentNumber > 1) ? currentNumber - 1 : 1;
    [self fetchComic:prev delegate:delegate];
}

- (void)fetchNextComic:(NSInteger)currentNumber delegate:(id<ComicNetworkDelegate>)delegate {
    NSInteger next = currentNumber + 1;
    // If we know max, clamp
    if (self.knownMaxComicNumber > 0 && next > self.knownMaxComicNumber) {
        next = self.knownMaxComicNumber;
    }
    [self fetchComic:next delegate:delegate];
}

- (Comic *)cachedComic:(NSInteger)number {
    return [[StorageManager sharedManager] loadComic:number];
}

#pragma mark - XKCDNetworkClientDelegate

- (void)networkClient:(id)client didFetchComic:(Comic *)comic error:(NSError *)error {
    if (comic) {
        self.currentComic = comic;
        if (comic.number > self.knownMaxComicNumber) {
            self.knownMaxComicNumber = comic.number;
        }
        // Track latest
        if (!self.latestComic || comic.number >= self.latestComic.number) {
            self.latestComic = comic;
        }

        [[StorageManager sharedManager] saveComic:comic];
        [[SearchManager sharedManager] addComicToIndex:comic];

        id<ComicNetworkDelegate> delegate = nil;
        @synchronized(self.pendingDelegates) {
            delegate = [self.pendingDelegates objectForKey:@(comic.number)];
            if (!delegate) {
                delegate = [self.pendingDelegates objectForKey:@(0)];
            }
            // Clean up after use
            if (delegate) {
                [self.pendingDelegates removeObjectForKey:@(comic.number)];
                [self.pendingDelegates removeObjectForKey:@(0)];
            }
        }

        if (delegate && [delegate respondsToSelector:@selector(comicFetched:)]) {
            [delegate comicFetched:comic];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDComicFetched" object:comic];
    } else if (error) {
        // Failure case: notify relevant delegates
        NSArray *keysToNotify = nil;
        @synchronized(self.pendingDelegates) {
            keysToNotify = [self.pendingDelegates allKeys];
        }
        // For simplicity, notify all pending with failure, then clear only 0 key if exists
        // Prefer to find delegate for failed number, but we don't know number on latest failure.
        // Try key 0 first
        id<ComicNetworkDelegate> delegateZero = nil;
        @synchronized(self.pendingDelegates) {
            delegateZero = [self.pendingDelegates objectForKey:@(0)];
            if (delegateZero) {
                [self.pendingDelegates removeObjectForKey:@(0)];
            }
        }
        if (delegateZero && [delegateZero respondsToSelector:@selector(comicFetchFailed:error:)]) {
            [delegateZero comicFetchFailed:0 error:error];
        } else {
            // If not zero, notify all remaining and clear
            @synchronized(self.pendingDelegates) {
                for (NSNumber *key in [self.pendingDelegates allKeys]) {
                    id<ComicNetworkDelegate> del = [self.pendingDelegates objectForKey:key];
                    if (del && [del respondsToSelector:@selector(comicFetchFailed:error:)]) {
                        [del comicFetchFailed:[key integerValue] error:error];
                    }
                }
                [self.pendingDelegates removeAllObjects];
            }
        }
    }
}

- (void)networkClient:(id)client didFetchImageData:(NSData *)data forComic:(NSInteger)comicNumber error:(NSError *)error {
    // Handled by ImageDownloader
}

@end

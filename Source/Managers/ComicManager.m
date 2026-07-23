#import "ComicManager.h"
#import "Managers/XKCDNetworkClient.h"
#import "Managers/StorageManager.h"
#import "Managers/ImageCache.h"
#import "Managers/ImageDownloader.h"
#import "Managers/SearchManager.h"
#import "Models/Comic.h"

@interface ComicManager ()
@property (nonatomic, strong) Comic *latestComic;
@property (nonatomic, strong) Comic *currentComic;
@property (nonatomic, strong) NSMutableDictionary *pendingDelegates;
@end

@implementation ComicManager

+ (instancetype)sharedManager {
    static ComicManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.pendingDelegates = [NSMutableDictionary dictionary];
    });
    return shared;
}

- (void)fetchComic:(NSInteger)number delegate:(id<ComicNetworkDelegate>)delegate {
    if (delegate) {
        [self.pendingDelegates setObject:delegate forKey:@(number)];
    }
    // Check storage first for offline support
    Comic *cached = [[StorageManager sharedManager] loadComic:number];
    if (cached && cached.number == number) {
        if (delegate && [delegate respondsToSelector:@selector(comicFetched:)]) {
            [delegate comicFetched:cached];
        }
        // Refresh in background
        [[XKCDNetworkClient sharedClient] fetchComicWithNumber:number delegate:self];
        return;
    }
    [[XKCDNetworkClient sharedClient] fetchComicWithNumber:number delegate:self];
}

- (void)fetchLatestComic:(id<ComicNetworkDelegate>)delegate {
    if (delegate) {
        [self.pendingDelegates setObject:delegate forKey:@(0)];
    }
    [[XKCDNetworkClient sharedClient] fetchLatestComicWithDelegate:self];
}

- (void)fetchRandomComic:(id<ComicNetworkDelegate>)delegate {
    if (delegate) {
        [self.pendingDelegates setObject:delegate forKey:@(0)];
    }
    // Strategy: fetch latest to know max, then pick random. For skeleton, we'll fetch latest endpoint.
    [[XKCDNetworkClient sharedClient] fetchLatestComicWithDelegate:self];
}

- (void)fetchPreviousComic:(NSInteger)currentNumber delegate:(id<ComicNetworkDelegate>)delegate {
    NSInteger prev = (currentNumber > 1) ? currentNumber - 1 : 1;
    [self fetchComic:prev delegate:delegate];
}

- (void)fetchNextComic:(NSInteger)currentNumber delegate:(id<ComicNetworkDelegate>)delegate {
    NSInteger next = currentNumber + 1;
    [self fetchComic:next delegate:delegate];
}

- (Comic *)cachedComic:(NSInteger)number {
    return [[StorageManager sharedManager] loadComic:number];
}

#pragma mark - XKCDNetworkClientDelegate

- (void)networkClient:(id)client didFetchComic:(Comic *)comic error:(NSError *)error {
    if (comic) {
        self.currentComic = comic;
        [[StorageManager sharedManager] saveComic:comic];
        [[SearchManager sharedManager] addComicToIndex:comic];

        id<ComicNetworkDelegate> delegate = [self.pendingDelegates objectForKey:@(comic.number)];
        if (!delegate) {
            delegate = [self.pendingDelegates objectForKey:@(0)];
        }
        if (delegate) {
            if ([delegate respondsToSelector:@selector(comicFetched:)]) {
                [delegate comicFetched:comic];
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDComicFetched" object:comic];
    } else if (error) {
        id<ComicNetworkDelegate> delegate = [self.pendingDelegates objectForKey:@(0)];
        if (delegate && [delegate respondsToSelector:@selector(comicFetchFailed:error:)]) {
            [delegate comicFetchFailed:0 error:error];
        }
    }
}

- (void)networkClient:(id)client didFetchImageData:(NSData *)data forComic:(NSInteger)comicNumber error:(NSError *)error {
    // Handled by ImageDownloader for image downloads.
}

#pragma mark - ComicNetworkProtocol

// Already implemented

@end

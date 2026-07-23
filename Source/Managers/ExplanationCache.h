#import <Foundation/Foundation.h>

@class Explanation;

@interface ExplanationCache : NSObject

+ (instancetype)sharedCache;
- (Explanation *)cachedExplanationForComic:(NSInteger)comicNumber;
- (void)cacheExplanation:(Explanation *)explanation;
- (void)clearCache;

@end

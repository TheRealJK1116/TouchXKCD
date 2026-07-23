#import <Foundation/Foundation.h>

@class Explanation;

@protocol ExplanationProviderDelegate <NSObject>
- (void)provider:(id)provider didFetchExplanation:(Explanation *)explanation error:(NSError *)error;
@end

@interface ExplanationProvider : NSObject

+ (instancetype)sharedProvider;
- (void)fetchExplanationForComic:(NSInteger)comicNumber delegate:(id<ExplanationProviderDelegate>)delegate;
- (Explanation *)cachedExplanationForComic:(NSInteger)comicNumber;
- (void)cacheExplanation:(Explanation *)explanation;
- (void)cacheExplanationFromString:(NSString *)body forComic:(NSInteger)comicNumber;

@end

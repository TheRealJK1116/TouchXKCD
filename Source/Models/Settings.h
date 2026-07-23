#import <Foundation/Foundation.h>

@interface Settings : NSObject <NSCoding>

@property (nonatomic, assign) BOOL showAltText;
@property (nonatomic, assign) BOOL offlineOnly;
@property (nonatomic, assign) BOOL autoDownloadNew;
@property (nonatomic, assign) BOOL darkMode;
@property (nonatomic, assign) NSInteger maxCacheSize;
@property (nonatomic, assign) BOOL firstLaunch;

- (void)synchronize;
- (void)resetToDefaults;

@end

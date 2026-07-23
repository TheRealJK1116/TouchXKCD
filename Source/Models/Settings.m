#import "Settings.h"

@implementation Settings

- (void)synchronize {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.showAltText forKey:@"showAltText"];
    [defaults setBool:self.offlineOnly forKey:@"offlineOnly"];
    [defaults setBool:self.autoDownloadNew forKey:@"autoDownloadNew"];
    [defaults setInteger:self.maxCacheSize forKey:@"maxCacheSize"];
    [defaults setBool:self.firstLaunch forKey:@"firstLaunch"];
    [defaults synchronize];
}

- (void)resetToDefaults {
    self.showAltText = YES;
    self.offlineOnly = NO;
    self.autoDownloadNew = YES;
    self.darkMode = NO;
    self.maxCacheSize = 200;
    self.firstLaunch = NO;
    [self synchronize];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeBool:self.showAltText forKey:@"showAltText"];
    [coder encodeBool:self.offlineOnly forKey:@"offlineOnly"];
    [coder encodeBool:self.autoDownloadNew forKey:@"autoDownloadNew"];
    [coder encodeBool:self.darkMode forKey:@"darkMode"];
    [coder encodeInteger:self.maxCacheSize forKey:@"maxCacheSize"];
    [coder encodeBool:self.firstLaunch forKey:@"firstLaunch"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.showAltText = [coder decodeBoolForKey:@"showAltText"];
        self.offlineOnly = [coder decodeBoolForKey:@"offlineOnly"];
        self.autoDownloadNew = [coder decodeBoolForKey:@"autoDownloadNew"];
        self.darkMode = [coder decodeBoolForKey:@"darkMode"];
        self.maxCacheSize = [coder decodeIntegerForKey:@"maxCacheSize"];
        self.firstLaunch = [coder decodeBoolForKey:@"firstLaunch"];
    }
    return self;
}

@end

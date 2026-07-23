#import "Settings.h"

@implementation Settings

- (instancetype)init {
    self = [super init];
    if (self) {
        // Default values per docs/MODELS.md
        _showAltText = YES;
        _offlineOnly = NO;
        _autoDownloadNew = YES;
        _darkMode = NO;
        _maxCacheSize = 200;
        _firstLaunch = YES;
    }
    return self;
}

- (void)synchronize {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.showAltText forKey:@"showAltText"];
    [defaults setBool:self.offlineOnly forKey:@"offlineOnly"];
    [defaults setBool:self.autoDownloadNew forKey:@"autoDownloadNew"];
    [defaults setBool:self.darkMode forKey:@"darkMode"];
    [defaults setInteger:self.maxCacheSize > 0 ? self.maxCacheSize : 200 forKey:@"maxCacheSize"];
    [defaults setBool:self.firstLaunch forKey:@"firstLaunch"];
    [defaults synchronize];
    // Post notification for UI to update
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TouchXKCDSettingsChanged" object:self];
}

- (void)resetToDefaults {
    self.showAltText = YES;
    self.offlineOnly = NO;
    self.autoDownloadNew = YES;
    self.darkMode = NO;
    self.maxCacheSize = 200;
    self.firstLaunch = YES;
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
        _showAltText = [coder decodeBoolForKey:@"showAltText"];
        _offlineOnly = [coder decodeBoolForKey:@"offlineOnly"];
        _autoDownloadNew = [coder decodeBoolForKey:@"autoDownloadNew"];
        _darkMode = [coder decodeBoolForKey:@"darkMode"];
        _maxCacheSize = [coder decodeIntegerForKey:@"maxCacheSize"];
        if (_maxCacheSize == 0) _maxCacheSize = 200;
        _firstLaunch = [coder decodeBoolForKey:@"firstLaunch"];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<Settings alt:%@ offline:%@ autoDL:%@ max:%ld>", self.showAltText?@"YES":@"NO", self.offlineOnly?@"YES":@"NO", self.autoDownloadNew?@"YES":@"NO", (long)self.maxCacheSize];
}

@end

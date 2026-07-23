#import "SettingsManager.h"

@implementation SettingsManager

+ (instancetype)sharedInstance {
    static SettingsManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (Settings *)currentSettings {
    Settings *settings = [[Settings alloc] init];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    settings.showAltText = [defaults boolForKey:@"showAltText"];
    settings.offlineOnly = [defaults boolForKey:@"offlineOnly"];
    settings.autoDownloadNew = [defaults boolForKey:@"autoDownloadNew"];
    settings.maxCacheSize = [defaults integerForKey:@"maxCacheSize"];
    if (settings.maxCacheSize == 0) settings.maxCacheSize = 200;
    settings.firstLaunch = [defaults boolForKey:@"firstLaunch"];
    return settings;
}

- (void)updateSetting:(NSString *)key value:(id)value {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:value forKey:key];
    [defaults synchronize];
}

@end

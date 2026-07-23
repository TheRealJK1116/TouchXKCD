#import "SettingsManager.h"

@implementation SettingsManager

+ (instancetype)sharedInstance {
    static SettingsManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        [shared registerDefaults];
    });
    return shared;
}

- (void)registerDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appDefaults = @{
        @"showAltText": @YES,
        @"offlineOnly": @NO,
        @"autoDownloadNew": @YES,
        @"maxCacheSize": @(200),
        @"firstLaunch": @YES,
        @"darkMode": @NO
    };
    [defaults registerDefaults:appDefaults];
}

- (Settings *)currentSettings {
    Settings *settings = [[Settings alloc] init];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Use objectForKey to detect existence, otherwise rely on registered defaults
    if ([defaults objectForKey:@"showAltText"] != nil) {
        settings.showAltText = [defaults boolForKey:@"showAltText"];
    } else {
        settings.showAltText = YES;
    }

    if ([defaults objectForKey:@"offlineOnly"] != nil) {
        settings.offlineOnly = [defaults boolForKey:@"offlineOnly"];
    } else {
        settings.offlineOnly = NO;
    }

    if ([defaults objectForKey:@"autoDownloadNew"] != nil) {
        settings.autoDownloadNew = [defaults boolForKey:@"autoDownloadNew"];
    } else {
        settings.autoDownloadNew = YES;
    }

    NSInteger maxSize = [defaults integerForKey:@"maxCacheSize"];
    settings.maxCacheSize = (maxSize > 0) ? maxSize : 200;

    if ([defaults objectForKey:@"firstLaunch"] != nil) {
        settings.firstLaunch = [defaults boolForKey:@"firstLaunch"];
    } else {
        settings.firstLaunch = YES;
    }

    if ([defaults objectForKey:@"darkMode"] != nil) {
        settings.darkMode = [defaults boolForKey:@"darkMode"];
    } else {
        settings.darkMode = NO;
    }

    return settings;
}

- (void)updateSetting:(NSString *)key value:(id)value {
    if (!key) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([value isKindOfClass:[NSNumber class]]) {
        // Preserve bool vs integer: use setBool for boolean keys
        if ([key isEqualToString:@"showAltText"] ||
            [key isEqualToString:@"offlineOnly"] ||
            [key isEqualToString:@"autoDownloadNew"] ||
            [key isEqualToString:@"firstLaunch"] ||
            [key isEqualToString:@"darkMode"]) {
            [defaults setBool:[value boolValue] forKey:key];
        } else if ([key isEqualToString:@"maxCacheSize"]) {
            [defaults setInteger:[value integerValue] forKey:key];
        } else {
            [defaults setObject:value forKey:key];
        }
    } else {
        [defaults setObject:value forKey:key];
    }
    [defaults synchronize];
}

@end

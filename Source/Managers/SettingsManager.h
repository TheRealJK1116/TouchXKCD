#import <Foundation/Foundation.h>
#import "Models/Settings.h"

@interface SettingsManager : NSObject

+ (instancetype)sharedInstance;
- (Settings *)currentSettings;
- (void)updateSetting:(NSString *)key value:(id)value;

@end

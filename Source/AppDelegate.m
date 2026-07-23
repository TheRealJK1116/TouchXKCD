#import "AppDelegate.h"
#import "Controllers/TouchXKCDTabBarController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    TouchXKCDTabBarController *tabController = [[TouchXKCDTabBarController alloc] init];
    self.window.rootViewController = tabController;

    [self.window makeKeyAndVisible];
    return YES;
}

- (void)dealloc {
    // ARC manages release; keep for explicit cleanup if needed
}

@end

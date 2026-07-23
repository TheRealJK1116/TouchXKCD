#import "AppDelegate.h"
#import "Controllers/TouchXKCDTabBarController.h"
#import "Managers/StorageManager.h"
#import "Managers/SettingsManager.h"
#import "Managers/ImageCache.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    // Initialize storage
    [[StorageManager sharedManager] initializeDatabase];

    // Initialize settings defaults
    [[SettingsManager sharedInstance] currentSettings];

    // Register for memory warnings
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

    // Setup root controller
    TouchXKCDTabBarController *tabController = [[TouchXKCDTabBarController alloc] init];
    self.window.rootViewController = tabController;

    [self.window makeKeyAndVisible];
    return YES;
}

- (void)handleMemoryWarning {
    [[ImageCache sharedCache] clearCache];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Resume queued downloads
    // Lazy import to avoid circular
    Class dmClass = NSClassFromString(@"DownloadManager");
    if (dmClass) {
        id mgr = [dmClass performSelector:@selector(sharedManager)];
        [mgr performSelector:@selector(resumeQueuedDownloads)];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Save queues etc. StorageManager and DownloadManager handle persistence internally
    Class dmClass = NSClassFromString(@"DownloadManager");
    if (dmClass) {
        id mgr = [dmClass performSelector:@selector(sharedManager)];
        [mgr performSelector:@selector(saveQueue)];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#import "TouchXKCDTabBarController.h"
#import "Controllers/ComicsViewController.h"
#import "Controllers/SearchViewController.h"
#import "Controllers/DownloadsViewController.h"
#import "Controllers/FavouritesViewController.h"
#import "Controllers/SettingsViewController.h"

@implementation TouchXKCDTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    ComicsViewController *comicsVC = [[ComicsViewController alloc] init];
    UINavigationController *comicsNav = [[UINavigationController alloc] initWithRootViewController:comicsVC];
    comicsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Comics" image:[UIImage imageNamed:@"tab_comics"] tag:0];

    SearchViewController *searchVC = [[SearchViewController alloc] init];
    UINavigationController *searchNav = [[UINavigationController alloc] initWithRootViewController:searchVC];
    searchNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Search" image:[UIImage imageNamed:@"tab_search"] tag:1];

    DownloadsViewController *downloadsVC = [[DownloadsViewController alloc] init];
    UINavigationController *downloadsNav = [[UINavigationController alloc] initWithRootViewController:downloadsVC];
    downloadsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Downloads" image:[UIImage imageNamed:@"tab_downloads"] tag:2];

    FavouritesViewController *favouritesVC = [[FavouritesViewController alloc] init];
    UINavigationController *favouritesNav = [[UINavigationController alloc] initWithRootViewController:favouritesVC];
    favouritesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Favourites" image:[UIImage imageNamed:@"tab_favourites"] tag:3];

    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings" image:[UIImage imageNamed:@"tab_settings"] tag:4];

    [self setViewControllers:@[comicsNav, searchNav, downloadsNav, favouritesNav, settingsNav]];
}

@end

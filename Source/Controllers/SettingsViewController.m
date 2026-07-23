#import "SettingsViewController.h"
#import "Managers/SettingsManager.h"
#import "Managers/StorageManager.h"
#import "Managers/DownloadManager.h"
#import "Managers/ImageCache.h"
#import "Managers/ExplanationCache.h"

@interface SettingsViewController ()
@property (nonatomic, strong) NSArray *sectionTitles;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.sectionTitles = @[@"General", @"Cache & Storage", @"Downloads", @"About"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.sectionTitles count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.sectionTitles objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 3; // Show Alt Text, Offline Only, Auto Download New
        case 1: return 3; // Clear Image Cache, Clear Explanation Cache, Storage Stats
        case 2: return 1; // Download Preferences (info)
        case 3: return 1; // About
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"SettingCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellId];
    }
    cell.accessoryType = UITableViewCellAccessoryNone;

    Settings *settings = [[SettingsManager sharedInstance] currentSettings];

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Show Alt Text";
                cell.accessoryType = settings.showAltText ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                break;
            case 1:
                cell.textLabel.text = @"Offline Only";
                cell.accessoryType = settings.offlineOnly ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                break;
            case 2:
                cell.textLabel.text = @"Auto Download New";
                cell.accessoryType = settings.autoDownloadNew ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                break;
        }
    } else if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Clear Image Cache";
                cell.accessoryType = UITableViewCellAccessoryNone;
                break;
            case 1:
                cell.textLabel.text = @"Clear Explanation Cache";
                cell.accessoryType = UITableViewCellAccessoryNone;
                break;
            case 2: {
                cell.textLabel.text = @"Storage Stats";
                NSInteger completed = [[DownloadManager sharedManager] completedCount];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld downloads", (long)completed];
                cell.accessoryType = UITableViewCellAccessoryNone;
                break;
            }
        }
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @"Maximum Cache Size";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld comics", (long)settings.maxCacheSize];
    } else if (indexPath.section == 3) {
        cell.textLabel.text = @"About TouchXKCD";
        cell.detailTextLabel.text = @"v1.0";
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Settings *settings = [[SettingsManager sharedInstance] currentSettings];

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                settings.showAltText = !settings.showAltText;
                [[SettingsManager sharedInstance] updateSetting:@"showAltText" value:@(settings.showAltText)];
                break;
            case 1:
                settings.offlineOnly = !settings.offlineOnly;
                [[SettingsManager sharedInstance] updateSetting:@"offlineOnly" value:@(settings.offlineOnly)];
                break;
            case 2:
                settings.autoDownloadNew = !settings.autoDownloadNew;
                [[SettingsManager sharedInstance] updateSetting:@"autoDownloadNew" value:@(settings.autoDownloadNew)];
                break;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [[ImageCache sharedCache] clearCache];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cache Cleared" message:@"Image cache cleared." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        } else if (indexPath.row == 1) {
            [[ExplanationCache sharedCache] clearCache];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cache Cleared" message:@"Explanation cache cleared." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"TouchXKCD v1.0" message:@"The definitive XKCD application for legacy iOS devices.\nBuilt for iPod touch 4G / iOS 6.1.6.\nNo Swift. No modern APIs. Pure native feel." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
    [self.tableView reloadData];
}

@end

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
    // Ensure tableView exists when used as UITableViewController root
    if (!self.tableView) {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        self.tableView.dataSource = self;
        self.tableView.delegate = self;
        [self.view addSubview:self.tableView];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.sectionTitles count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < [self.sectionTitles count]) {
        return [self.sectionTitles objectAtIndex:section];
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 3; // Show Alt Text, Offline Only, Auto Download New
        case 1: return 4; // Clear Image Cache, Clear Explanation Cache, Clear File Cache, Storage Stats
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
    cell.detailTextLabel.text = nil;

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
                break;
            case 1:
                cell.textLabel.text = @"Clear Explanation Cache";
                break;
            case 2:
                cell.textLabel.text = @"Clear File Cache (Images)";
                break;
            case 3: {
                cell.textLabel.text = @"Storage Stats";
                NSInteger completed = [[DownloadManager sharedManager] completedCount];
                NSInteger allComics = [[[StorageManager sharedManager] loadAllComics] count];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld dl, %ld comics", (long)completed, (long)allComics];
                break;
            }
        }
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @"Maximum Cache Size";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld comics", (long)settings.maxCacheSize];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 3) {
        cell.textLabel.text = @"About TouchXKCD";
        cell.detailTextLabel.text = @"v1.0";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cache Cleared" message:@"Image memory cache cleared." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        } else if (indexPath.row == 1) {
            [[ExplanationCache sharedCache] clearCache];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cache Cleared" message:@"Explanation cache cleared." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        } else if (indexPath.row == 2) {
            // Clear file cache in ~/Library/Caches/TouchXKCD/images
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"TouchXKCD/images"];
            NSFileManager *fm = [NSFileManager defaultManager];
            NSError *err = nil;
            NSArray *files = [fm contentsOfDirectoryAtPath:cacheDir error:&err];
            NSInteger removed = 0;
            for (NSString *file in files) {
                NSString *fullPath = [cacheDir stringByAppendingPathComponent:file];
                if ([fm removeItemAtPath:fullPath error:nil]) removed++;
            }
            [[ImageCache sharedCache] clearCache];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cache Cleared" message:[NSString stringWithFormat:@"Removed %ld image files.", (long)removed] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cache Size" message:@"Enter max cache size (comics):" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Set", nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        alert.tag = 100;
        UITextField *tf = [alert textFieldAtIndex:0];
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.placeholder = [NSString stringWithFormat:@"%ld", (long)settings.maxCacheSize];
        [alert show];
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"TouchXKCD v1.0" message:@"The definitive XKCD application for legacy iOS devices.\nBuilt for iPod touch 4G / iOS 6.1.6.\nNo Swift. No modern APIs. Pure native feel.\n\n XKCD content by Randall Munroe." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        alert.tag = 200;
        [alert show];
    }
    [self.tableView reloadData];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 100 && buttonIndex == 1) {
        // Only handle cache size alert
        if (alertView.alertViewStyle == UIAlertViewStylePlainTextInput) {
            UITextField *textField = [alertView textFieldAtIndex:0];
            if (!textField) return;
            NSString *text = textField.text;
            NSInteger size = [text integerValue];
            if (size > 0 && size <= 10000) {
                [[SettingsManager sharedInstance] updateSetting:@"maxCacheSize" value:@(size)];
                [self.tableView reloadData];
            } else if (size > 0) {
                UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Invalid Size" message:@"Please enter a value between 1 and 10000." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [err show];
            }
        }
    }
    // For tag 200 (About) or others, do nothing — prevents crash from accessing textField when style is default
}

@end

#import "FavouritesViewController.h"
#import "Controllers/ComicDetailViewController.h"
#import "Managers/ComicManager.h"
#import "Models/Comic.h"
#import "Managers/StorageManager.h"
#import "Models/Favourite.h"

@interface FavouritesViewController ()
@property (nonatomic, strong) NSArray *favourites;
@end

@implementation FavouritesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Favourites";
    if (!self.tableView) {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    }
    self.tableView.rowHeight = 60.0f;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear All" style:UIBarButtonItemStyleBordered target:self action:@selector(clearAll)];
    [self refreshData];
}

- (void)clearAll {
    if ([self.favourites count] == 0) return;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Clear Favourites?" message:@"Remove all favourites?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Clear", nil];
    alert.tag = 999;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 999 && buttonIndex == 1) {
        NSArray *all = [Favourite allFavourites];
        for (Favourite *fav in all) {
            [fav remove];
        }
        [self refreshData];
    }
}

- (void)refreshData {
    NSArray *allFavs = [Favourite allFavourites];
    // Sort by addedAt descending
    self.favourites = [allFavs sortedArrayUsingComparator:^NSComparisonResult(Favourite *a, Favourite *b) {
        if (!a.addedAt && !b.addedAt) return NSOrderedSame;
        if (!a.addedAt) return NSOrderedDescending;
        if (!b.addedAt) return NSOrderedAscending;
        return [b.addedAt compare:a.addedAt];
    }];
    [self.tableView reloadData];

    if ([self.favourites count] == 0) {
        UILabel *emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, 320, 40)];
        emptyLabel.text = @"No favourites yet.\nTap Fav in Comics tab to add.";
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.numberOfLines = 2;
        emptyLabel.textColor = [UIColor grayColor];
        emptyLabel.font = [UIFont systemFontOfSize:14.0f];
        emptyLabel.tag = 1234;
        // Remove previous empty label if any
        UIView *prev = [self.view viewWithTag:1234];
        [prev removeFromSuperview];
        [self.view addSubview:emptyLabel];
    } else {
        UIView *prev = [self.view viewWithTag:1234];
        [prev removeFromSuperview];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.favourites count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"FavouriteCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.row >= [self.favourites count]) return cell;
    Favourite *fav = [self.favourites objectAtIndex:indexPath.row];
    Comic *comic = [[StorageManager sharedManager] loadComic:fav.comicNumber];
    if (comic && comic.title) {
        cell.textLabel.text = [NSString stringWithFormat:@"#%ld - %@", (long)fav.comicNumber, comic.title];
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"Comic #%ld", (long)fav.comicNumber];
    }
    if (comic && comic.dateString) {
        cell.detailTextLabel.text = comic.dateString;
    } else if (fav.addedAt) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateStyle:NSDateFormatterShortStyle];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Added: %@", [df stringFromDate:fav.addedAt]];
    } else {
        cell.detailTextLabel.text = @"";
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= [self.favourites count]) return;
    Favourite *fav = [self.favourites objectAtIndex:indexPath.row];
    ComicDetailViewController *detailVC = [[ComicDetailViewController alloc] init];
    detailVC.comicNumber = fav.comicNumber;
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (indexPath.row >= [self.favourites count]) return;
        Favourite *fav = [self.favourites objectAtIndex:indexPath.row];
        [fav remove];
        NSMutableArray *mutable = [self.favourites mutableCopy];
        [mutable removeObjectAtIndex:indexPath.row];
        self.favourites = [mutable copy];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        if ([self.favourites count] == 0) {
            [self refreshData];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshData];
}

@end

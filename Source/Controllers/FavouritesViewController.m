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
    self.tableView.rowHeight = 60.0f;
    [self refreshData];
}

- (void)refreshData {
    self.favourites = [Favourite allFavourites];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.favourites count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"FavouriteCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
    }
    Favourite *fav = [self.favourites objectAtIndex:indexPath.row];
    Comic *comic = [[StorageManager sharedManager] loadComic:fav.comicNumber];
    cell.textLabel.text = comic.title ? comic.title : [NSString stringWithFormat:@"Comic #%ld", (long)fav.comicNumber];
    cell.detailTextLabel.text = comic.dateString ? comic.dateString : [NSString stringWithFormat:@"Added: %@", [fav.addedAt description]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Favourite *fav = [self.favourites objectAtIndex:indexPath.row];
    ComicDetailViewController *detailVC = [[ComicDetailViewController alloc] init];
    detailVC.comicNumber = fav.comicNumber;
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Favourite *fav = [self.favourites objectAtIndex:indexPath.row];
        [fav remove];
        [self refreshData];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshData];
}

@end

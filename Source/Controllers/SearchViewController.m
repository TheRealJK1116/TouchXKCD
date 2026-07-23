#import "SearchViewController.h"
#import "Controllers/ComicDetailViewController.h"
#import "Managers/SearchManager.h"
#import "Models/Comic.h"

@implementation SearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Search";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    self.searchBar.placeholder = @"Search XKCD...";
    self.searchBar.delegate = self;
    [self.view addSubview:self.searchBar];

    self.resultsTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, 320, 436) style:UITableViewStylePlain];
    self.resultsTableView.dataSource = self;
    self.resultsTableView.delegate = self;
    [self.view addSubview:self.resultsTableView];

    self.searchResults = [NSArray array];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *query = searchBar.text;
    if (query && query.length > 0) {
        self.searchResults = [[SearchManager sharedManager] searchResults:query];
        [self.resultsTableView reloadData];
        [searchBar resignFirstResponder];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.searchResults = [NSArray array];
        [self.resultsTableView reloadData];
    } else if (searchText.length >= 2) {
        self.searchResults = [[SearchManager sharedManager] searchResults:searchText];
        [self.resultsTableView reloadData];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.searchResults count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"SearchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
    }

    Comic *comic = [self.searchResults objectAtIndex:indexPath.row];
    cell.textLabel.text = comic.title ? comic.title : [NSString stringWithFormat:@"Comic #%ld", (long)comic.number];
    cell.detailTextLabel.text = comic.dateString ? comic.dateString : @"Unknown date";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Comic *comic = [self.searchResults objectAtIndex:indexPath.row];
    ComicDetailViewController *detailVC = [[ComicDetailViewController alloc] init];
    detailVC.comicNumber = comic.number;
    [self.navigationController pushViewController:detailVC animated:YES];
}

@end

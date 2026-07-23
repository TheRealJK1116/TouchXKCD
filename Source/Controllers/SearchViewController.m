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
    self.searchBar.placeholder = @"FindXKCD: search transcripts, titles, alt...";
    self.searchBar.delegate = self;
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.showsCancelButton = YES;
    [self.view addSubview:self.searchBar];

    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 44, 300, 20)];
    infoLabel.text = @"Offline search of cached comics (title, alt, transcript, explanation)";
    infoLabel.font = [UIFont systemFontOfSize:10.0f];
    infoLabel.textColor = [UIColor grayColor];
    infoLabel.backgroundColor = [UIColor clearColor];
    infoLabel.tag = 999;
    infoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:infoLabel];

    self.resultsTableView.frame = CGRectMake(0, 64, 320, 416);

    self.resultsTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, 320, 436) style:UITableViewStylePlain];
    self.resultsTableView.dataSource = self;
    self.resultsTableView.delegate = self;
    self.resultsTableView.rowHeight = 60.0f;
    self.resultsTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.resultsTableView];

    self.searchResults = [NSArray array];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Rebuild Index" style:UIBarButtonItemStyleBordered target:self action:@selector(rebuildIndex)];
}

- (void)rebuildIndex {
    self.searchBar.text = @"Rebuilding index...";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [[SearchManager sharedManager] rebuildSearchIndex];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.searchBar.text = @"";
            self.searchResults = [NSArray array];
            [self.resultsTableView reloadData];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Index Rebuilt" message:@"Search index rebuilt from cached comics." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        });
    });
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query && query.length > 0) {
        self.searchResults = [[SearchManager sharedManager] searchResults:query];
        [self.resultsTableView reloadData];
        [searchBar resignFirstResponder];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    self.searchResults = [NSArray array];
    [self.resultsTableView reloadData];
    [searchBar resignFirstResponder];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSString *trimmed = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        self.searchResults = [NSArray array];
        [self.resultsTableView reloadData];
    } else if (trimmed.length >= 2) {
        // Debounce: dispatch after short delay to avoid excessive queries
        // For simplicity, query immediately but on background queue
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSArray *results = [[SearchManager sharedManager] searchResults:trimmed];
            dispatch_async(dispatch_get_main_queue(), ^{
                // Only update if still same query
                if ([searchBar.text isEqualToString:searchText]) {
                    self.searchResults = results;
                    [self.resultsTableView reloadData];
                }
            });
        });
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
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.row >= [self.searchResults count]) return cell;

    Comic *comic = [self.searchResults objectAtIndex:indexPath.row];
    cell.textLabel.text = comic.title ? comic.title : [NSString stringWithFormat:@"Comic #%ld", (long)comic.number];
    if (comic.dateString) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"#%ld - %@", (long)comic.number, comic.dateString];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Comic #%ld", (long)comic.number];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= [self.searchResults count]) return;
    Comic *comic = [self.searchResults objectAtIndex:indexPath.row];
    ComicDetailViewController *detailVC = [[ComicDetailViewController alloc] init];
    detailVC.comicNumber = comic.number;
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    self.searchResults = [NSArray array];
    [self.resultsTableView reloadData];
}

@end

#import "DownloadsViewController.h"
#import "Managers/DownloadManager.h"
#import "Managers/DownloadTask.h"

@interface DownloadsViewController ()
@property (nonatomic, strong) NSArray *currentTasks;
@end

@implementation DownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Downloads";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.selectedSegment = 0;

    NSArray *items = @[@"Active", @"Done", @"Failed"];
    self.segmentControl = [[UISegmentedControl alloc] initWithItems:items];
    self.segmentControl.frame = CGRectMake(50, 10, 220, 28);
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.segmentControl.selectedSegmentIndex = 0;
    [self.view addSubview:self.segmentControl];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 50, 320, 390) style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 60.0f;
    [self.view addSubview:self.tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshData) name:@"TouchXKCDDownloadProgressUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshData) name:@"TouchXKCDDownloadCompleted" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshData) name:@"TouchXKCDDownloadFailed" object:nil];

    [self refreshData];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.selectedSegment = sender.selectedSegmentIndex;
    [self refreshData];
    [self.tableView reloadData];
}

- (void)refreshData {
    DownloadManager *mgr = [DownloadManager sharedManager];
    switch (self.selectedSegment) {
        case 0:
            self.currentTasks = [mgr activeTasks];
            break;
        case 1:
            self.currentTasks = [mgr completedTasks];
            break;
        case 2:
            self.currentTasks = [mgr failedTasks];
            break;
        default:
            self.currentTasks = [NSArray array];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.currentTasks count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"DownloadCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
    }
    DownloadTask *task = [self.currentTasks objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"Comic #%ld", (long)task.comicNumber];
    NSString *subtitle = @"";
    switch (self.selectedSegment) {
        case 0:
            subtitle = [NSString stringWithFormat:@"Progress: %.0f%% - %ld retries", task.progress * 100.0f, (long)task.retryCount];
            break;
        case 1:
            subtitle = [NSString stringWithFormat:@"Completed - %ld bytes", (long)task.localPath.length];
            break;
        case 2:
            subtitle = [NSString stringWithFormat:@"Failed after %ld retries", (long)task.retryCount];
            break;
        default:
            subtitle = @"Unknown";
    }
    cell.detailTextLabel.text = subtitle;
    if (self.selectedSegment == 0) {
        UIProgressView *pv = (UIProgressView *)[cell.contentView viewWithTag:100];
        if (!pv) {
            pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            pv.frame = CGRectMake(120, 35, 180, 10);
            pv.tag = 100;
            [cell.contentView addSubview:pv];
        }
        pv.progress = task.progress;
        pv.hidden = NO;
    } else {
        UIProgressView *pv = (UIProgressView *)[cell.contentView viewWithTag:100];
        if (pv) pv.hidden = YES;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    DownloadTask *task = [self.currentTasks objectAtIndex:indexPath.row];
    if (self.selectedSegment == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cancel Download?" message:[NSString stringWithFormat:@"Cancel download for comic #%ld?", (long)task.comicNumber] delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
        alert.tag = indexPath.row + self.selectedSegment * 1000;
        [alert show];
    } else if (self.selectedSegment == 1) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Open Comic" message:[NSString stringWithFormat:@"Open comic #%ld?", (long)task.comicNumber] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Open", nil];
        alert.tag = indexPath.row + self.selectedSegment * 1000;
        [alert show];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSInteger index = (alertView.tag / 1000) % 3;
    NSInteger row = alertView.tag % 1000;
    if (buttonIndex == 1) {
        if (index == 0) {
            DownloadTask *task = [self.currentTasks objectAtIndex:row];
            [[DownloadManager sharedManager] cancelTask:task];
        } else if (index == 1) {
            DownloadTask *task = [self.currentTasks objectAtIndex:row];
            UIAlertView *msg = [[UIAlertView alloc] initWithTitle:@"Opening" message:[NSString stringWithFormat:@"Opening comic #%ld", (long)task.comicNumber] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [msg show];
        }
    }
    [self refreshData];
    [self.tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

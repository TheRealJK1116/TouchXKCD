#import "DownloadsViewController.h"
#import "Managers/DownloadManager.h"
#import "Managers/DownloadTask.h"
#import "Controllers/ComicDetailViewController.h"

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
    self.segmentControl.frame = CGRectMake(10, 10, 300, 28);
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.segmentControl.selectedSegmentIndex = 0;
    self.segmentControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.segmentControl];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 50, 320, 390) style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 60.0f;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear Failed" style:UIBarButtonItemStyleBordered target:self action:@selector(clearFailed)];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDownloadNotification:) name:@"TouchXKCDDownloadProgressUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDownloadNotification:) name:@"TouchXKCDDownloadCompleted" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDownloadNotification:) name:@"TouchXKCDDownloadFailed" object:nil];

    [self refreshData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshData];
    [self.tableView reloadData];
}

- (void)handleDownloadNotification:(NSNotification *)notif {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshData];
        [self.tableView reloadData];
    });
}

- (void)clearFailed {
    NSArray *failed = [[DownloadManager sharedManager] failedTasks];
    for (DownloadTask *task in failed) {
        [[DownloadManager sharedManager] removeTask:task];
    }
    [self refreshData];
    [self.tableView reloadData];
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
    if (!self.currentTasks) self.currentTasks = [NSArray array];
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
    if (indexPath.row >= [self.currentTasks count]) {
        return cell;
    }
    DownloadTask *task = [self.currentTasks objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"Comic #%ld", (long)task.comicNumber];
    NSString *subtitle = @"";
    switch (self.selectedSegment) {
        case 0:
            subtitle = [NSString stringWithFormat:@"Progress: %.0f%% - %ld retries", task.progress * 100.0f, (long)task.retryCount];
            break;
        case 1: {
            NSString *path = task.localPath;
            unsigned long long fileSize = 0;
            if (path) {
                NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
                fileSize = [attrs fileSize];
            }
            if (fileSize > 1024) {
                subtitle = [NSString stringWithFormat:@"Completed - %.1f KB", fileSize / 1024.0];
            } else if (fileSize > 0) {
                subtitle = [NSString stringWithFormat:@"Completed - %llu bytes", fileSize];
            } else {
                subtitle = @"Completed";
            }
            break;
        }
        case 2:
            subtitle = [NSString stringWithFormat:@"Failed after %ld retries", (long)task.retryCount];
            break;
        default:
            subtitle = @"Unknown";
    }
    cell.detailTextLabel.text = subtitle;
    cell.accessoryType = (self.selectedSegment == 0) ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;

    // Progress view handling
    UIProgressView *pv = (UIProgressView *)[cell.contentView viewWithTag:100];
    if (self.selectedSegment == 0) {
        if (!pv) {
            pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            pv.frame = CGRectMake(15, 42, 280, 10);
            pv.tag = 100;
            pv.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:pv];
        }
        pv.progress = task.progress;
        pv.hidden = NO;
    } else {
        if (pv) pv.hidden = YES;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= [self.currentTasks count]) return;
    DownloadTask *task = [self.currentTasks objectAtIndex:indexPath.row];
    if (self.selectedSegment == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Cancel Download?" message:[NSString stringWithFormat:@"Cancel download for comic #%ld?", (long)task.comicNumber] delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
        // Encode segment and row in tag: segment*10000 + row
        alert.tag = self.selectedSegment * 10000 + indexPath.row;
        [alert show];
    } else if (self.selectedSegment == 1) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Open Comic" message:[NSString stringWithFormat:@"Open comic #%ld?", (long)task.comicNumber] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Open", nil];
        alert.tag = self.selectedSegment * 10000 + indexPath.row;
        [alert show];
    } else if (self.selectedSegment == 2) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Retry?" message:[NSString stringWithFormat:@"Retry download for comic #%ld?", (long)task.comicNumber] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Retry", @"Remove", nil];
        alert.tag = self.selectedSegment * 10000 + indexPath.row;
        [alert show];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (indexPath.row < [self.currentTasks count]) {
            DownloadTask *task = [self.currentTasks objectAtIndex:indexPath.row];
            [[DownloadManager sharedManager] removeTask:task];
            [self refreshData];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSInteger segment = alertView.tag / 10000;
    NSInteger row = alertView.tag % 10000;
    if (row < 0 || row >= [self.currentTasks count]) {
        [self refreshData];
        [self.tableView reloadData];
        return;
    }
    DownloadTask *task = [self.currentTasks objectAtIndex:row];

    if (segment == 0) {
        if (buttonIndex == 1) {
            [[DownloadManager sharedManager] cancelTask:task];
        }
    } else if (segment == 1) {
        if (buttonIndex == 1) {
            ComicDetailViewController *detail = [[ComicDetailViewController alloc] init];
            detail.comicNumber = task.comicNumber;
            [self.navigationController pushViewController:detail animated:YES];
        }
    } else if (segment == 2) {
        if (buttonIndex == 1) {
            // Retry: remove from failed and re-add
            [[DownloadManager sharedManager] removeTask:task];
            [[DownloadManager sharedManager] downloadComic:task.comicNumber delegate:nil];
        } else if (buttonIndex == 2) {
            [[DownloadManager sharedManager] removeTask:task];
        }
    }
    [self refreshData];
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

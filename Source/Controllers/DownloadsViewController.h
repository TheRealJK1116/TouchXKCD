#import <UIKit/UIKit.h>

@interface DownloadsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, assign) NSInteger selectedSegment;

@end

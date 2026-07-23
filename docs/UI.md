# TouchXKCD — UI Navigation Design

---

## 1. Navigation Flow Diagrams

### 1.1 Main Tab Flow
```
+-------------------------------------------------------------------+
|                         TouchXKCDTabBarController                 |
|  (UITabBarController, classic iOS 6 style)                        |
+-------------------------------------------------------------------+
         |                |               |               |              |
    [Comics]         [Search]        [Downloads]    [Favourites]  [Settings]
         |                |               |               |              |
+--------v--------+ +-----v------+ +----v-------+ +----v------+ +-----v------+
|ComicsNavCtrl   | |SearchNavCtrl| |DownloadsNav| |FavNavCtrl | |SettingsNav |
|UINavigationController  ... (same pattern for all tabs)           |
+----------------+ +-------------+ +-------------+ +-----------+ +------------+
         |                |               |               |              |
+--------v--------+ +-----v------+------+----v------+ +----v------+       |
|ComicsTableVC   | |UISearchDisplayController (iOS 6 native)       |        |
|UITableViewController  (with search bar + results table)          |        |
+----------------+ +--------------------------------------------+       |
         |                                                                   |
+--------v--------+                                                          |
|ComicDetailVC  |                                                          |
|UIViewController (image + scroll text)                                  |
+----------------+                                                          |
```

### 1.2 Comics Tab Flow
```
ComicsTab (UITabBarItem: Comics)
  └── NavController (root: ComicsTableVC)
        └── Root: ComicsTableVC (UITableViewController, grouped style option)
              - Sections: Latest Comics / Archive (optional grouping)
              - Cells: ComicThumbnailCell (image + title + date)
              - Actions: Tap -> Push ComicDetailVC
              - Pull-to-refresh -> Fetch latest from network
        └── Push: ComicDetailVC
              - Header: Comic image (UIScrollView + UIImageView, zoomable)
              - Body: Title (UILabel), Date (UILabel), Alt text (UITextView, optional)
              - Explanation: UITextView (scrollable, links to Explanation DB)
              - Footer: Favourite toggle (UIButton), Download button

### 1.3 Search Tab Flow
```
SearchTab (UITabBarItem: Search)
  └── NavController (root: SearchVC)
        └── Root: SearchVC (UIViewController + UISearchDisplayController)
              - Search Bar: UISearchBar (scope buttons optional)
              - Results Table: UITableViewController embedded
              - Actions: Tap result -> Push ComicDetailVC
        └── Push: ComicDetailVC (same as Comics)

### 1.4 Downloads Tab Flow
```
DownloadsTab (UITabBarItem: Downloads)
  └── NavController (root: DownloadsTableVC)
        └── Root: DownloadsTableVC (UITableViewController)
              - Sections: Active / Completed / Failed
              - Cells: DownloadTaskCell (thumbnail + title + progress bar)
              - Actions: Tap completed -> Push ComicDetailVC; Tap active -> cancel
        └── Push: ComicDetailVC (optional, only for completed)

### 1.5 Favourites Tab Flow
```
FavouritesTab (UITabBarItem: Favourites)
  └── NavController (root: FavouritesTableVC)
        └── Root: FavouritesTableVC (UITableViewController)
              - Cells: FavouriteCell (thumbnail + title + note snippet)
              - Actions: Tap -> Push ComicDetailVC; Swipe -> Delete
        └── Push: ComicDetailVC

### 1.6 Settings Tab Flow
```
SettingsTab (UITabBarItem: Settings)
  └── NavController (root: SettingsTableVC)
        └── Root: SettingsTableVC (UITableViewController, grouped style)
              - Sections:
                1. General (Show alt text, Auto-download new, Offline only)
                2. Cache (Clear image cache, Current cache size)
                3. About (App name, version, XKCD attribution)
              - Actions: Toggle switches update Settings singleton immediately
        └── No push navigation (settings are self-contained)
```

---

## 2. UI Design Principles (iOS 6 Premium Native)

- **Colors**: 
  - Background: `#EFEFF4` (classic grouped table background)
  - Navigation bar: `#F6F6F6` with `tintColor` `#007AFF` (system blue)
  - Tab bar: `#F8F8F8` with active tint `#007AFF`
- **Typography**: 
  - System font `UIFont` (Helvetica)
  - Title: 17pt, bold; Body: 14pt; Caption: 12pt
- **Shadows**: Light `shadowOffset` `(0, 1)` with `shadowOpacity` 0.2 for navigation bars
- **Buttons**: `UIBarButtonItem` with `done` / `action` style; custom buttons use rounded rect with gradient background image (optional for premium feel)
- **Images**: 
  - Comic display uses `UIImageView` with `contentMode` `UIViewContentModeScaleAspectFit`
  - Thumbnail cells use `contentModeScaleAspectFill` with clipping
- **Animations**: 
  - Push/pop uses standard `UINavigationController` transition
  - Download progress updates via `UIProgressView` embedded in cell

---

## 3. Navigation Controller Setup

In `TouchXKCDAppDelegate`:
```objc
UITabBarController *tabController = [[TouchXKCDTabBarController alloc] init];

UINavigationController *comicsNav = [[UINavigationController alloc] initWithRootViewController:[[ComicsViewController alloc] init]];
comicsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Comics" image:[UIImage imageNamed:@"tab_comics"] tag:0];

// Repeat for Search, Downloads, Favourites, Settings

[tabController setViewControllers:@[comicsNav, searchNav, downloadsNav, favNav, settingsNav]];

self.window.rootViewController = tabController;
```

---

## 4. State Restoration (iOS 6)

- `UIViewControllerRestoration` available in iOS 6; implement `encodeRestorableStateWithCoder:` and `decodeRestorableStateWithCoder:` for `ComicDetailVC` to restore viewed comic number.
- `UIPersistantStorage` not required; SQLite handles persistence.

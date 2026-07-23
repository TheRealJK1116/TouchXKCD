# TouchXKCD — Architecture Document

Target: iPod touch 4th generation | iOS 6.1.6 | ARMv7 | ARC | Theos

---

## 1. Application Architecture

### 1.1 Overview
TouchXKCD is a native UIKit application using the classic iOS 6 design language (gloss, gradients, skeuomorphism, standard UITabBarController). It uses manual reference counting (ARC) with zero third-party dependencies.

### 1.2 Layer Diagram
```
+---------------------------+
|        UIViewControllers   |
|  (Comics, Search, Downloads,|
|   Favourites, Settings)     |
+---------------------------+
|         Managers            |
|  ComicManager, DownloadMgr, |
|  StorageMgr, SearchMgr      |
+---------------------------+
|         Data Models          |
|  Comic, Explanation, Task,  |
|  Favourite, Settings        |
+---------------------------+
|         Storage              |
|  SQLite + File Cache        |
+---------------------------+
```

---

## 2. Controller Hierarchy

### 2.1 Root Controller
- `TouchXKCDTabBarController` extends `UITabBarController`
- Five tabs, each embedded in a `UINavigationController`

### 2.2 Tab Controllers
1. **Comics** (`ComicsViewController`)
   - Root: `ComicsTableViewController`
   - Push: `ComicDetailViewController`
2. **Search** (`SearchViewController`)
   - Root: `SearchTableViewController`
   - Push: `ComicDetailViewController`
3. **Downloads** (`DownloadsViewController`)
   - Root: `DownloadsTableViewController` (shows active / completed tasks)
4. **Favourites** (`FavouritesViewController`)
   - Root: `FavouritesTableViewController`
   - Push: `ComicDetailViewController`
5. **Settings** (`SettingsViewController`)
   - Root: `SettingsTableViewController` (grouped style)

### 2.3 Controller Flow
```
TabBarController
├── Comics (Nav) ──► ComicsList ──► ComicDetail
├── Search (Nav) ──► SearchList ──► ComicDetail
├── Downloads (Nav) ──► DownloadsList ──► ComicDetail (optional)
├── Favourites (Nav) ──► FavouritesList ──► ComicDetail
└── Settings (Nav) ──► SettingsList (no push)
```

---

## 3. Storage Architecture

### 3.1 Database: SQLite
- Path: `~/Library/Application Support/TouchXKCD/store.sqlite`
- Schema:
  - `comics` (id INTEGER PRIMARY KEY, number INTEGER, title TEXT, img_url TEXT, alt_text TEXT, transcript TEXT, link_url TEXT, date_str TEXT)
  - `explanations` (comic_id INTEGER PRIMARY KEY, body TEXT, references TEXT)
  - `downloads` (task_id INTEGER PRIMARY KEY, comic_id INTEGER UNIQUE, status INTEGER, path TEXT)
  - `favourites` (comic_id INTEGER PRIMARY KEY)
  - `search_index` (term TEXT, comic_id INTEGER)

### 3.2 File Cache
- Path: `~/Library/Caches/TouchXKCD/images/`
- Naming: `{comic_number}.png` / `.jpg`
- Max size: 50MB (pruned on low memory warning)

### 3.3 Settings Storage
- `NSUserDefaults` for lightweight preferences (`firstLaunch`, `showAltText`, `offlineOnly`)
- Plist backup in `~/Library/Preferences/com.touchxkcd.plist`

---

## 4. Networking Architecture

### 4.1 Transport
- `NSURLConnection` (iOS 6 compatible)
- No `NSURLSession` (not available on iOS 6 without modern APIs)
- Timeout: 30s
- User-Agent: `TouchXKCD/1.0 (iPod touch; iOS 6.1.6)`

### 4.2 Protocol
- XKCD JSON endpoint: `https://xkcd.com/{number}/info.0.json`
- Image endpoint: derived from `img` field in JSON

### 4.3 Queue
- `NSOperationQueue` with maxConcurrentOperationCount = 2
- Queue names: `com.touchxkcd.network`

---

## 5. Download Architecture

### 5.1 DownloadTask Model
- `comicNumber`
- `imageURL`
- `status` (pending / downloading / completed / failed)
- `progress` (float 0.0–1.0)
- `localPath`

### 5.2 DownloadManager
- Manages a queue of `DownloadTask`
- Writes completed images to file cache
- Updates SQLite `downloads` table
- Emits `DownloadDelegateProtocol` notifications

### 5.3 Offline Strategy
- Before downloading, check cache
- If cached, skip download
- If no network (`Reachability` via SystemConfiguration framework), queue tasks
- On `UIApplicationWillEnterForeground`, resume queued downloads

---

## 6. Caching Architecture

### 6.1 Memory Cache
- `NSCache` for `UIImage` objects (max 10MB)
- Key: `comicNumber` as NSString
- Auto-evicted on memory warning

### 6.2 Disk Cache
- SQLite for metadata
- File system for images
- Pruning policy:
  - Least Recently Used (LRU) based on `last_accessed` timestamp in DB
  - Max 200 comics cached locally (~50MB)

---

## 7. Search Architecture

### 7.1 SearchIndex
- SQLite table `search_index`
- Terms derived from:
  - Comic title
  - Alt text (`alt`)
  - Transcript (`transcript`)
- Tokenization: split on whitespace, lowercase, strip punctuation

### 7.2 Search Flow
1. User types query
2. `SearchIndex` performs `LIKE '%term%'` query on `search_index`
3. Results sorted by relevance (`comic_number` DESC for recency, optional boost for title matches)
4. `Comic` objects hydrated from DB by IDs
5. Displayed in `UISearchDisplayController` (iOS 6 native)

---

## 8. Explanation Architecture

### 8.1 Data Source
- XKCD Explain wiki endpoint (optional future)
- Fallback: user-submitted or cached `explanation` from DB
- `Explanation` model links 1:1 with `Comic`

### 8.2 UI
- `ComicDetailViewController` shows comic image at top
- `UITextView` scrollable for explanation text
- References parsed into `UIButton` links for external URLs

---

## 9. Memory Management Strategy

- **ARC enabled** globally (`-fobjc-arc` in Makefile for all `.m` files)
- **Manual retain/release** avoided; rely on compiler
- **Image memory**:
  - Load thumbnails (150px) for lists using `+[UIImage imageWithContentsOfFile:]`
  - Load full images only in detail view
  - `UIImageJPEGRepresentation` / `PNGRepresentation` for temporary encoding never held in memory simultaneously with source
- **Table view**:
  - `UITableView` uses `dequeueReusableCellWithIdentifier:`
  - Only visible cells hold images
  - `prepareForReuse` clears image references
- **Memory warnings**:
  - `didReceiveMemoryWarning` flushes `NSCache`, reloads visible tables without images, triggers disk cache pruning

---

## 10. Offline Strategy

- **Read-only offline mode**: all cached comics viewable
- **Download queue persistence**: SQLite `downloads` table persists queued tasks across app restarts
- **Network detection**: `Reachability` (SystemConfiguration) detects `kSCNetworkReachabilityFlagsReachable`
- **UI feedback**: `UIActivityIndicatorView` shows when online sync is active; status bar shows connection state
- **Settings toggle**: `offlineOnly` prevents any network requests when enabled

---

## 11. Security & Privacy

- No analytics libraries
- No tracking cookies
- SQLite DB not encrypted (acceptable for public comic data on jailbroken device)
- No user account required

---

## 12. Build & Deployment

- **Makefile**: Theos standard (`ARCHS = armv7`)
- **SDK**: iPhoneSDK 6.1 (or compatible Theos SDK)
- **Deployment**: `.deb` package for Theos repository, or `.app` for manual install
- **Signing**: Ad-hoc / Developer (no App Store; jailbreak device)

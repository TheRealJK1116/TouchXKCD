# TouchXKCD — Data Model Design

Objective-C, ARC, iOS 6.1.6 compatible.

---

## 1. Comic

**File**: `Source/Models/Comic.h` / `.m`

**Properties** (nonatomic, strong where appropriate):
- `NSInteger number`
- `NSString *title`
- `NSString *imageURL`
- `NSString *altText`
- `NSString *transcript`
- `NSString *linkURL`
- `NSString *dateString` (e.g., "2024-01-15")
- `NSDate *parsedDate`
- `NSString *explanationBody` (denormalized for display; linked to Explanation)

**Methods**:
- `+ (instancetype)comicWithNumber:(NSInteger)num;`
- `- (BOOL)isCached;`
- `- (NSString *)cachedImagePath;`
- `- (void)hydrateFromDictionary:(NSDictionary *)dict;`

**Persistence**: SQLite `comics` table; `NSCoding` for temporary memory objects.

---

## 2. Explanation

**File**: `Source/Models/Explanation.h` / `.m`

**Properties**:
- `NSInteger comicNumber` (primary key, 1:1 with Comic)
- `NSString *body` (markdown-style plain text, max ~10KB)
- `NSArray *references` (array of NSString URLs)
- `NSString *author` (optional)
- `NSDate *lastUpdated`

**Methods**:
- `+ (instancetype)explanationForComic:(NSInteger)comicNumber;`
- `- (NSString *)formattedBody;`

---

## 3. DownloadTask

**File**: `Source/Managers/DownloadTask.h` / `.m`

**Properties**:
- `NSInteger taskID` (auto-increment)
- `NSInteger comicNumber`
- `NSString *imageURL` (original remote URL)
- `NSString *localPath` (cached file path)
- `NSInteger status` (enum: pending = 0, downloading = 1, completed = 2, failed = 3)
- `float progress`
- `NSDate *createdAt`
- `NSDate *completedAt`

**Methods**:
- `- (void)startDownload;`
- `- (void)cancel;`
- `- (BOOL)isActive;`

---

## 4. Favourite

**File**: `Source/Models/Favourite.h` / `.m`

**Properties**:
- `NSInteger comicNumber`
- `NSDate *addedAt`
- `NSString *note` (optional user note, max 200 chars)

**Methods**:
- `+ (NSArray *)allFavourites;`
- `+ (BOOL)isFavourite:(NSInteger)comicNumber;`
- `- (void)add;`
- `- (void)remove;`

---

## 5. Settings

**File**: `Source/Managers/Settings.h` / `.m`

**Singleton**: `[Settings sharedInstance]`

**Properties** (backed by `NSUserDefaults`):
- `BOOL showAltText`
- `BOOL offlineOnly`
- `BOOL autoDownloadNew` (auto-download on app launch if online)
- `BOOL darkMode` (not applicable for iOS 6, reserved)
- `NSInteger maxCacheSize` (default 200)
- `BOOL firstLaunch`

**Methods**:
- `- (void)synchronize;`
- `- (void)resetToDefaults;`

---

## 6. SearchIndex

**File**: `Source/Managers/SearchIndex.h` / `.m`

**Properties**:
- `sqlite3 *databaseHandle` (internal, not exposed)

**Methods**:
- `- (NSArray *)resultsForQuery:(NSString *)query;` (returns array of `Comic` objects)
- `- (void)rebuildIndex:(NSArray *)comics;`
- `- (void)addComic:(Comic *)comic;`
- `- (void)removeComic:(Comic *)comic;`

**Tokenization Strategy**:
- Split on whitespace
- Lowercase
- Strip punctuation (`!@#$%^&*()...`)
- Ignore words shorter than 3 chars (stop words optional)
- Store `term -> comic_id` in SQLite

---

## 7. Protocols

### ComicNetworkProtocol
```objc
@protocol ComicNetworkProtocol <NSObject>
- (void)fetchComic:(NSInteger)number delegate:(id<ComicNetworkDelegate>)delegate;
@end
```

### ComicNetworkDelegate
```objc
@protocol ComicNetworkDelegate <NSObject>
- (void)comicFetched:(Comic *)comic;
- (void)comicFetchFailed:(NSInteger)number error:(NSError *)error;
@end
```

### DownloadDelegateProtocol
```objc
@protocol DownloadDelegateProtocol <NSObject>
- (void)downloadTask:(DownloadTask *)task didUpdateProgress:(float)progress;
- (void)downloadTaskDidComplete:(DownloadTask *)task;
- (void)downloadTaskDidFail:(DownloadTask *)task;
@end
```

### StorageProtocol
```objc
@protocol StorageProtocol <NSObject>
- (void)saveComic:(Comic *)comic;
- (Comic *)loadComic:(NSInteger)number;
- (NSArray *)loadAllComics;
- (void)deleteComic:(NSInteger)number;
@end
```

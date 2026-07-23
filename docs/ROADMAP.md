# TouchXKCD — Implementation Roadmap

---

## Milestone 1: Project Skeleton (Current)
**Duration**: 1-2 days  
**Deliverables**:
- Complete architecture documentation (ARCHITECTURE.md, MODELS.md, STORAGE.md, UI.md)
- Theos Makefile and `control` file
- Data model classes (Comic, Explanation, DownloadTask, Favourite, Settings, SearchIndex)
- Manager stubs (ComicManager, StorageManager, DownloadManager, SearchManager, SettingsManager)
- Controller skeletons (all 5 tabs + ComicDetailVC + SearchVC + DownloadsVC)
- Protocol definitions (ComicNetworkProtocol, DownloadDelegateProtocol, StorageProtocol)
- Empty `.xib` / `.storyboard` alternatives (programmatic UI for iOS 6 compatibility)
- Project builds successfully (`make` produces `.app` or `.deb` without errors)

**Status**: In Progress

---

## Milestone 2: Storage & Database Layer
**Duration**: 3-4 days  
**Deliverables**:
- SQLite schema creation and migration scripts
- StorageManager implementation (CRUD for comics, explanations, favourites, downloads)
- File system cache management (LRU pruning, path resolution)
- Unit tests for SQLite operations (optional, using basic assertions)
- Memory footprint verification (< 20MB for DB layer)

---

## Milestone 3: Networking & Download
**Duration**: 4-5 days  
**Deliverables**:
- ComicNetworkProtocol implementation using `NSURLConnection`
- JSON parsing (`NSJSONSerialization` available in iOS 5+)
- DownloadManager with `NSOperationQueue` and progress tracking
- Image download to file cache
- Offline detection via `Reachability`
- Queue persistence (SQLite) across app restarts

---

## Milestone 4: Search Architecture
**Duration**: 2-3 days  
**Deliverables**:
- SearchIndex table creation
- Tokenizer and index builder
- SearchDisplayController integration in SearchVC
- Real-time query results from SQLite
- Performance optimization (limit 20 results, index only title + alt + transcript)

---

## Milestone 5: UI Polish & Controllers
**Duration**: 5-7 days  
**Deliverables**:
- Complete `ComicsTableVC` with thumbnail cells
- `ComicDetailVC` with zoomable image, scrollable explanation, favourite button
- `DownloadsTableVC` with progress bars and cancel functionality
- `FavouritesTableVC` with swipe-to-delete
- `SettingsTableVC` with grouped table style and toggles
- Custom cell subclasses for premium look
- Navigation bar styling consistent with iOS 6 premium apps
- Memory warning handling (`didReceiveMemoryWarning` flushes caches)

---

## Milestone 6: Integration & Offline Mode
**Duration**: 3-4 days  
**Deliverables**:
- End-to-end flow: search -> detail -> download -> favourite -> settings
- Offline mode toggling
- Auto-download of new comics on launch
- Cache size enforcement and pruning
- First launch setup wizard (optional, guided by `firstLaunch` flag)
- Error handling for all network failures with user-friendly alerts (`UIAlertView`)

---

## Milestone 7: Testing & Build
**Duration**: 3-5 days  
**Deliverables**:
- Build verification on device (iPod touch 4G, iOS 6.1.6)
- Memory profiling with Instruments (Leaks, Allocations, Activity Monitor)
- Flash storage profiling (database size, cache growth over 500 comics)
- User acceptance testing for premium native feel
- Final `.deb` packaging and repository upload
- Documentation update (user guide, troubleshooting)

---

## Milestone 8: Future Enhancements (Post-Release)
- XKCD Explain wiki integration (explanation retrieval)
- Comic sharing via `UIActivityViewController` (iOS 6 compatible)
- Dark theme option (using custom drawing)
- Notification for new comics (`UILocalNotification`)
- iPad universal binary support (optional, same codebase)

# TouchXKCD Architecture Notes

## Controller Hierarchy

```
TouchXKCDTabBarController
├── ComicsNavController (ComicsViewController)
├── SearchNavController (SearchViewController)
├── DownloadsNavController (DownloadsViewController)
├── FavouritesNavController (FavouritesViewController)
├── SettingsNavController (SettingsViewController)
└── ExplanationNavController (ExplanationViewController - pushed from Comics)
```

## Data Flow

Network (`XKCDNetworkClient`) -> Parser (`ComicParser`) -> Model (`Comic`) -> Controller (`ComicsViewController`)
Storage (`StorageManager`) -> Persistence (file archive / SQLite) -> Cache (`ImageCache`, `ExplanationCache`)
Search (`SearchIndex` + `SearchManager`) -> SQLite LIKE queries -> Results (`SearchViewController`)
Favourites (`Favourite` + `StorageManager`) -> File archive -> List (`FavouritesViewController`)
Downloads (`DownloadTask` + `DownloadManager`) -> Queue persistence (`NSKeyedArchiver`) -> Progress tracking (`DownloadDelegateProtocol`)

## Key Design Decisions

- `NSURLConnection` for iOS 6 compatibility
- File-based persistence for downloads, favourites, explanations (low overhead)
- SQLite index for search (fast LIKE queries, incremental updates)
- `NSCache` for image memory management (count limit 30)
- `ARC` globally enabled
- No Swift, no modern APIs, no third-party libraries
- Memory budget: < 50MB resident, suitable for 256MB RAM device

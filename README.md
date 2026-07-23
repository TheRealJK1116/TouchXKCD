# TouchXKCD

The definitive XKCD application for legacy iOS devices.

## Target Platform

- iPod touch 4th generation
- iOS 6.1.6
- ARMv7
- Objective-C
- UIKit
- ARC enabled
- Theos application

## Features

- Comic reader with latest, previous, next, random, and jump-to-number navigation
- Offline archive download (individual, range, full archive) with retry and progress tracking
- Search by comic number, title, and alt text (SQLite index, offline-capable)
- Favourites with persistent storage and swipe-to-delete
- Explanation retrieval with caching and graceful offline handling
- Memory-conscious image caching and smooth scrolling

## Architecture

- `ComicsViewController`: main reader UI
- `ComicDetailViewController`: detail view
- `SearchViewController`: search interface
- `DownloadsViewController`: download queue display
- `FavouritesViewController`: favourites list
- `SettingsViewController`: preferences, cache management, about
- `ExplanationViewController`: explanation display

Managers:
- `ComicManager`: networking and comic retrieval
- `XKCDNetworkClient`: `NSURLConnection` transport
- `ComicParser`: JSON parsing
- `StorageManager`: file persistence for comics
- `DownloadManager`: download queue, retry, persistence
- `ImageCache`: in-memory image cache (`NSCache`)
- `ImageDownloader`: async image download with file caching
- `SearchManager` / `SearchIndex`: SQLite-based search index
- `SettingsManager`: user preferences
- `ExplanationProvider` / `ExplanationCache`: explanation retrieval and caching

Protocols:
- `ComicNetworkProtocol`
- `DownloadDelegateProtocol`
- `StorageProtocol`

## Build Instructions

This is a Theos application. Ensure Theos is installed and the SDK points to iOS 6.1.

```bash
make

# Install .deb package
make install
```

Requirements:
- Theos build environment
- iPhone SDK 6.1 or compatible
- `sqlite3` library (included in `Makefile` via `TouchXKCD_LIBRARIES`)

## Memory & Storage Strategy

- `NSCache` (max 30 images) for memory efficiency
- Image files stored in `~/Library/Caches/TouchXKCD/images/`
- SQLite index for search (`search_index.sqlite`)
- File archive persistence for downloads (`queue.archive`), favourites (`favourites.archive`), and explanations (`explanations/`)
- `ARC` enabled globally (`-fobjc-arc`)

## Offline Strategy

- Comics cached locally via `StorageManager`
- Downloads queued persistently across restarts
- Search index built from cached comics
- Favourites stored in file archive
- Explanations cached locally
- Network failures show cached content with status indicators

## License

Licensed under GNU General Public License v3. See `LICENSE`.

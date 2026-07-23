# TouchXKCD — Storage Design

---

## 1. Requirements

- Scale to entire XKCD archive (~3,000 comics at time of writing, growing ~1/week)
- Efficient on flash storage (iPod touch 4G uses flash NAND, no SSD controller)
- Low memory footprint (target < 20MB resident for DB + cache managers)
- Suitable for 256MB RAM device (system uses ~100MB, app budget ~50MB)

---

## 2. SQLite Schema

### 2.1 Tables

**comics**
```sql
CREATE TABLE IF NOT EXISTS comics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  number INTEGER UNIQUE NOT NULL,
  title TEXT,
  img_url TEXT,
  alt_text TEXT,
  transcript TEXT,
  link_url TEXT,
  date_str TEXT,
  updated_at INTEGER DEFAULT 0
);
CREATE INDEX idx_comics_number ON comics(number);
CREATE INDEX idx_comics_title ON comics(title);
```

**explanations**
```sql
CREATE TABLE IF NOT EXISTS explanations (
  comic_id INTEGER PRIMARY KEY,
  body TEXT,
  references TEXT,
  last_updated INTEGER DEFAULT 0,
  FOREIGN KEY (comic_id) REFERENCES comics(number) ON DELETE CASCADE
);
CREATE INDEX idx_explanations_comic ON explanations(comic_id);
```

**downloads**
```sql
CREATE TABLE IF NOT EXISTS downloads (
  task_id INTEGER PRIMARY KEY AUTOINCREMENT,
  comic_id INTEGER UNIQUE,
  status INTEGER DEFAULT 0,
  path TEXT,
  progress REAL DEFAULT 0.0,
  created_at INTEGER DEFAULT 0,
  completed_at INTEGER DEFAULT 0
);
CREATE INDEX idx_downloads_status ON downloads(status);
CREATE INDEX idx_downloads_comic ON downloads(comic_id);
```

**favourites**
```sql
CREATE TABLE IF NOT EXISTS favourites (
  comic_id INTEGER PRIMARY KEY,
  note TEXT DEFAULT '',
  added_at INTEGER DEFAULT 0
);
CREATE INDEX idx_favourites_added ON favourites(added_at DESC);
```

**search_index**
```sql
CREATE TABLE IF NOT EXISTS search_index (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  term TEXT NOT NULL,
  comic_id INTEGER NOT NULL
);
CREATE INDEX idx_search_term ON search_index(term);
CREATE INDEX idx_search_comic ON search_index(comic_id);
CREATE UNIQUE INDEX idx_search_unique ON search_index(term, comic_id);
```

### 2.2 Performance
- PRAGMA journal_mode = WAL (supported on iOS 6.1.6 SQLite 3.7+)
- PRAGMA synchronous = NORMAL (balance durability/performance)
- PRAGMA cache_size = -2048 (2MB page cache, low memory)
- PRAGMA temp_store = MEMORY (faster, acceptable for small queries)

---

## 3. File System Cache

### 3.1 Image Cache
- Directory: `~/Library/Caches/TouchXKCD/images/`
- File naming: `{comic_number}.jpg` (or `.png` if original is PNG)
- Max files: 200 (configurable in Settings)
- Pruning: LRU based on `atime` of file; delete oldest when count > max

### 3.2 Cache Metadata DB
- Separate SQLite DB (`cache_meta.sqlite`) or table in main DB
- Columns: `comic_id`, `filename`, `file_size_bytes`, `last_accessed`, `is_complete`
- Enables quick lookup without scanning directory

---

## 4. Low Memory Footprint Strategy

- **Lazy loading**: `Comic` objects loaded only when needed; table cells load thumbnails on-demand
- **Batch inserts**: When fetching new comics, insert into DB in batches of 50 (not one-by-one)
- **Memory-mapped images**: Not available on iOS 6 UIKit; use `+[UIImage imageWithContentsOfFile:]` which loads lazily from file and releases memory quickly
- **No full archive preload**: Never load all comics into memory; paginate at 50 results max
- **DB connection pooling**: Single `sqlite3` connection per thread (main thread only for reads; background queue for writes)

---

## 5. Flash Storage Efficiency

- SQLite files compacted via `VACUUM` on startup if database has grown > 20% since last vacuum
- Image files stored in native format (JPEG for photos, PNG for line art); no transcoding to save CPU
- No duplicate storage: image saved once; DB references path string only
- Small page size: 1024 bytes (`PRAGMA page_size = 1024`) to reduce internal fragmentation for small records

---

## 6. Backup & Restore

- SQLite DB included in `~/Library/Application Support/TouchXKCD/store.sqlite`
- Image cache excluded from iTunes backup (set `NSURLIsExcludedFromBackupKey` equivalent via `setResourceValue:forKey:error:` on iOS 6)
- Settings included in `NSUserDefaults` which is backed up automatically

# Build Instructions

## Prerequisites

- Theos build environment
- iPhone SDK 6.1 (or compatible Theos SDK)
- `sqlite3` library (linked automatically via Makefile)

## Build

```bash
# Clean build
make clean

# Build application
make

# Package .deb for Theos repository
make package

# Install on device (requires connected jailbroken device)
make install
```

## Makefile Variables

- `ARCHS = armv7`
- `TARGET_IPHONEOS_DEPLOYMENT_VERSION = 6.1`
- `TouchXKCD_LIBRARIES = sqlite3`
- `TouchXKCD_CFLAGS = -fobjc-arc -I. -I./Source`

## Target Device

- iPod touch 4th generation
- iOS 6.1.6
- ARMv7 architecture

## Verification

The project uses:
- `NSURLConnection` (iOS 6 compatible)
- `ARC` (`-fobjc-arc`)
- No Swift
- No modern iOS APIs (`NSURLSession`, etc.)
- No third-party libraries

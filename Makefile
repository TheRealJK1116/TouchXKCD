# TouchXKCD Makefile
# Theos application for iOS 6.1.6 / ARMv7 / ARC

ARCHS = armv7
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 6.1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TouchXKCD
TouchXKCD_FILES = Source/main.m Source/AppDelegate.m \
    Source/Controllers/ComicsViewController.m Source/Controllers/ComicDetailViewController.m \
    Source/Controllers/SearchViewController.m Source/Controllers/DownloadsViewController.m \
    Source/Controllers/FavouritesViewController.m Source/Controllers/SettingsViewController.m \
    Source/Controllers/TouchXKCDTabBarController.m Source/Controllers/ExplanationViewController.m \
    Source/Managers/ComicManager.m Source/Managers/StorageManager.m \
    Source/Managers/DownloadManager.m Source/Managers/SearchManager.m \
    Source/Managers/SettingsManager.m Source/Managers/DownloadTask.m Source/Managers/SearchIndex.m Source/Managers/XKCDNetworkClient.m Source/Managers/ExplanationProvider.m Source/Managers/ExplanationCache.m Source/Managers/ComicParser.m Source/Managers/ImageCache.m Source/Managers/ImageDownloader.m \
    Source/Models/Comic.m Source/Models/Explanation.m \
    Source/Models/Favourite.m Source/Models/Settings.m

TouchXKCD_FRAMEWORKS = UIKit CoreGraphics QuartzCore Foundation SystemConfiguration
TouchXKCD_LIBRARIES = sqlite3 stdc++

TouchXKCD_CFLAGS = -fobjc-arc -I. -I./Source

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 \"TouchXKCD\" || true"

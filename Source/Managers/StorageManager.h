#import <Foundation/Foundation.h>
#import "Protocols/StorageProtocol.h"

@class Comic;

@interface StorageManager : NSObject <StorageProtocol>

+ (instancetype)sharedManager;
- (BOOL)initializeDatabase;
- (void)vacuumIfNeeded;

@end

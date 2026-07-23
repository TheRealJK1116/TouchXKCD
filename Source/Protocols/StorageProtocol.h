#import <Foundation/Foundation.h>

@class Comic;

@protocol StorageProtocol <NSObject>
- (void)saveComic:(Comic *)comic;
- (Comic *)loadComic:(NSInteger)number;
- (NSArray *)loadAllComics;
- (void)deleteComic:(NSInteger)number;
@end

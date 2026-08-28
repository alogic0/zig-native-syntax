#import <Foundation/Foundation.h>
// Objective-C corpus
@interface Demo
@property(nonatomic, copy) NSString *title;
- (BOOL)run:(id)value count:(NSInteger)count;
@end
NSString *text = "x\n<&>"; BOOL ok = true; int n = 42;
id make() { return [Demo run:text count:n]; }

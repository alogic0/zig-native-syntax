#import <Foundation/Foundation.h>

@protocol DataSource <NSObject>
- (void)loadItemAtIndex:
    (NSUInteger)index
    completion:(void (^)(id item, NSError *error))completion;
@end

@interface Store<ObjectType> : NSObject <DataSource>
@property(nonatomic, copy) NSArray<ObjectType> *items;
@end

void (^handler)(BOOL success, NSError *error) = ^(BOOL success, NSError *error) {
    NSArray<NSString *> *values = @[@"one", @"two", @YES];
    NSDictionary<NSString *, NSNumber *> *payload = @{@"count": @2};
    SEL action = @selector(loadItemAtIndex:completion:);
    [values enumerateObjectsUsingBlock:^(NSString *value, NSUInteger index, BOOL *stop) {
        NSLog(@"%@ %lu", value, (unsigned long)index);
    }];
};

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN


@interface XCUIDevice (MTCTap)

- (void)mtc_tap:(CGPoint)point;

- (void)mtc_longtap:(CGPoint)point duration:(CGFloat)duration;

- (void)mtc_drag:(CGPoint)fromPoint to:(CGPoint)toPoint;

- (void)mtc_swipe_up;
- (void)mtc_swipe_down;
- (void)mtc_swipe_right;
- (void)mtc_swipe_left;
- (void)mtc_random_swipe:(int)time;

- (void)mtc_monkey_start_with_limit_count:(int)count;
- (void)mtc_monkey_end;

@end

NS_ASSUME_NONNULL_END

#import "XCUIDevice+MTCTap.h"
#import "XCEventGenerator.h"

#import "FBAlert.h"

#import "FBMacros.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBApplication.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
#import "XCAXClient_iOS.h"
#import "XCAccessibilityElement.h"

#import "UIDevice-Hardware.h"

@implementation XCUIDevice (MTCTap)

static NSString *monkey_state = @"init";
static int monkey_count = 0;
static int max_monkey_count = 100;
static FBApplication *app;

- (void)mtc_device_render_screen_bound {
    
}

- (void)mtc_tap:(CGPoint)point {
    NSLog(@"tap at %fx%f", point.x, point.y);
    XCEventGenerator *eventGenerator = [XCEventGenerator sharedGenerator];
    XCEventGeneratorHandler handle = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
    };
    if ([eventGenerator respondsToSelector:@selector(tapAtTouchLocations:numberOfTaps:orientation:handler:)]) {
        [eventGenerator tapAtTouchLocations:@[[NSValue valueWithCGPoint:point]] numberOfTaps:1 orientation:UIInterfaceOrientationPortrait handler:handle];
    }
    else {
        [eventGenerator tapAtPoint:point orientation:UIInterfaceOrientationPortrait handler:handle];
    }
}

- (void)mtc_longtap:(CGPoint)point duration:(CGFloat)duration {
    if (duration > 2.0f) {
        duration = 2.0f;
    }
    NSLog(@"longtap at %fx%f, duration %f", point.x, point.y, duration);
    XCEventGenerator *eventGenerator = [XCEventGenerator sharedGenerator];
    [eventGenerator pressAtPoint:point forDuration:duration orientation:UIInterfaceOrientationPortrait handler:^(XCSynthesizedEventRecord *record, NSError *commandError) {
    }];
}

- (void)mtc_drag:(CGPoint)fromPoint to:(CGPoint)toPoint {
  NSLog(@"drag at %fx%f to %fx%f, duration %f", fromPoint.x, fromPoint.y,
        toPoint.x, toPoint.y, 0.2f);
  XCEventGenerator *eventGenerator = [XCEventGenerator sharedGenerator];
  [eventGenerator pressAtPoint:fromPoint forDuration:0.1f liftAtPoint:toPoint velocity:1000 orientation:UIInterfaceOrientationPortrait name:@"swipe" handler:^(XCSynthesizedEventRecord *record, NSError *commandError) {
  }];
}

- (void)mtc_drag_path:(NSArray *)points {
  NSDictionary *firstPoint = [points firstObject];
  XCPointerEventPath *path = [[XCPointerEventPath alloc]
                              initForTouchAtPoint:CGPointMake([[firstPoint valueForKey:@"x"] floatValue],
                                                              [[firstPoint valueForKey:@"y"] floatValue])
                              offset:0.0];
  for (unsigned int i = 1; i < [points count]; i++) {
    NSDictionary *point = [points objectAtIndex:i];
    [path moveToPoint:CGPointMake([[point valueForKey:@"x"] floatValue],
                                  [[point valueForKey:@"y"] floatValue])
     atOffset:[[point valueForKey:@"offset"] floatValue]];
  }
  [path liftUpAtOffset:[[[points lastObject] valueForKey:@"offset"] floatValue]];
  XCSynthesizedEventRecord *r = [[XCSynthesizedEventRecord alloc] initWithName:@"path" interfaceOrientation:UIInterfaceOrientationPortrait];
  [r addPointerEventPath:path];
  [r synthesizeWithError:nil];
  NSLog(@"darg path %@", [path pointerEvents]);
}

- (void)mtc_swipe_up {
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGPoint fromPoint = CGPointMake((int32_t)screenBound.size.width / 2, (int32_t)screenBound.size.height * 3 / 4);
    CGPoint toPoint = CGPointMake((int32_t)screenBound.size.width / 2, (int32_t)screenBound.size.height / 4);
    [self mtc_drag:fromPoint to:toPoint];
}

- (void)mtc_swipe_down {
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGPoint fromPoint = CGPointMake((int32_t)screenBound.size.width / 2, (int32_t)screenBound.size.height * 1 / 4);
    CGPoint toPoint = CGPointMake((int32_t)screenBound.size.width / 2, (int32_t)screenBound.size.height * 3 / 4);
    [self mtc_drag:fromPoint to:toPoint];
}

- (void)mtc_swipe_left {
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGPoint fromPoint = CGPointMake((int32_t)screenBound.size.width * 1 / 4, (int32_t)screenBound.size.height / 2);
    CGPoint toPoint = CGPointMake((int32_t)screenBound.size.width * 3 / 4, (int32_t)screenBound.size.height / 2);
    [self mtc_drag:fromPoint to:toPoint];
}

- (void)mtc_swipe_right {
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGPoint fromPoint = CGPointMake((int32_t)screenBound.size.width * 3 / 4, (int32_t)screenBound.size.height / 2);
    CGPoint toPoint = CGPointMake((int32_t)screenBound.size.width * 1 / 4, (int32_t)screenBound.size.height / 2);
    [self mtc_drag:fromPoint to:toPoint];
}

- (void)mtc_random_swipe:(int)time {
    int op = arc4random() % 4;
    for (int i = 0; i < time; i += 1) {
        if (op == 0) {
            [self mtc_swipe_up];
        } else if (op == 1) {
            [self mtc_swipe_down];
        } else if (op == 2) {
            [self mtc_swipe_left];
        } else if (op == 3) {
            [self mtc_swipe_right];
        }
    }
}

- (CGPoint)mtc_random_point {
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    //CGRect screenBound = [[UIScreen mainScreen] nativeBounds];
    return CGPointMake(arc4random() % (int32_t)screenBound.size.width,
                       arc4random() % ((int32_t)screenBound.size.height - 35) + 20);
}

- (void)mtc_random_tap {
    [self mtc_tap:[self mtc_random_point]];
}

- (void)mtc_random_drag {
    [self mtc_drag:[self mtc_random_point] to:[self mtc_random_point]];
}


+ (NSArray *)dictionaryForElement:(XCElementSnapshot *)snapshot
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    info[@"name"] = FBValueOrNull(snapshot.wdName);
    info[@"value"] = FBValueOrNull(snapshot.wdValue);
    info[@"label"] = FBValueOrNull(snapshot.wdLabel);
    info[@"rect"] = snapshot.wdRect;
    if ((snapshot.elementType == XCUIElementTypeButton) ||
        (snapshot.elementType == XCUIElementTypeMenuButton) ||
        (snapshot.elementType == XCUIElementTypeToolbarButton) ||
        (snapshot.elementType == XCUIElementTypeKey) ||
        (snapshot.elementType == XCUIElementTypeLink) ||
        (snapshot.elementType == XCUIElementTypeTextField) ||
        (snapshot.elementType == XCUIElementTypeSecureTextField) ||
        
        (snapshot.elementType == XCUIElementTypeCell) ||
        (snapshot.elementType == XCUIElementTypeLayoutItem)
        ){
        [result addObject:info];
    }
    NSArray *childElements = snapshot.children;
    if ([childElements count]) {
        info[@"children"] = [[NSMutableArray alloc] init];
        for (XCElementSnapshot *childSnapshot in childElements) {
            if ([childSnapshot isWDEnabled] && [childSnapshot isWDVisible]) {
                [result addObjectsFromArray:[self dictionaryForElement:childSnapshot]];
            }
        }
    }
    return result;
}

- (void)mtc_random_element_tap {
    //FBApplication *app = [FBApplication fb_activeApplication];
    [app query];
    //[app resolve];
    
    NSArray *tapAbleElements = [self.class dictionaryForElement:[app lastSnapshot]];
    NSLog(@"%@", tapAbleElements);
    if ([tapAbleElements count] > 0) {
        NSDictionary *ele = [tapAbleElements objectAtIndex:arc4random() % [tapAbleElements count]];
        NSLog(@"tap %@", [ele objectForKey:@"label"]);
        NSDictionary *rect = (NSDictionary *)[ele valueForKey:@"rect"];
        CGPoint point = CGPointMake([[rect valueForKey:@"x"] integerValue] + [[rect valueForKey:@"width"]integerValue] / 2,
                                    [[rect valueForKey:@"y"] integerValue] + [[rect valueForKey:@"height"] integerValue] / 2);
        [self mtc_tap:point];
    }
}

- (void)mtc_monkey {
    if ([monkey_state isEqualToString:@"init"]) {
        monkey_state = @"running";
        app = [FBApplication fb_activeApplication];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (int i = 0; ; i++) {
                if ([monkey_state isEqualToString:@"running"]) {
                    monkey_count += 1;
                    if (monkey_count > max_monkey_count) {
                        monkey_state = @"timeout";
                        continue;
                    }
                    int op = arc4random() % 100;
                    if (op < 80) {
                        [self mtc_random_tap];
                    } else if (op < 90) {
                        [self mtc_random_swipe:5];
                        monkey_count += 4;
                    } else {
                        [self mtc_random_drag];
                    }
                    [NSThread sleepForTimeInterval:0.2f];
                } else {
                    //NSLog(@"bb %d", i);
                    [NSThread sleepForTimeInterval:3.0f];
                }
            }
        });
    }
}

- (void)mtc_monkey_start_with_limit_count:(int)count {
    max_monkey_count = monkey_count + count;
    if ([monkey_state isEqualToString:@"init"]) {
        [self mtc_monkey];
    } else {
        monkey_state = @"running";
    }
}

- (void)mtc_monkey_end {
    if ([monkey_state isEqualToString:@"init"]) {
    } else {
        monkey_state = @"stop";
    }
}

@end

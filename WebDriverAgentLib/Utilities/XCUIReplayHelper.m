//
//  XCUIReplayHelper.m
//  XCUITestWrap
//
//  Created by 项光特 on 04/09/2017.
//  Copyright © 2017 项光特. All rights reserved.
//

#import "XCUIReplayHelper.h"


#import "XCAccessibilityElement.h"
#import "XCUIElement.h"
#import "XCUIApplicationImpl.h"
#import "XCUIApplication.h"
#import "XCElementSnapshot.h"
#import "XCAXClient_iOS.h"
#import "XCUIDevice+MTCTap.h"
#import "XCUIDevice+MTCAppHelper.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"

#import "XCTestDriver.h"
#import "XCTRunnerDaemonSession.h"
#import <objc/runtime.h>

@interface XCUIReplayHelper ()

@end

@implementation XCUIReplayHelper

- (id)init {
  if ((self = [super init])) {
    self.app = nil;
    self.lastError = nil;
    return self;
  } else {
    return nil;
  }
}

- (id)initWithApp:(XCUIApplication *)app {
  if ((self = [super init])) {
    self.app = app;
    self.lastError = nil;
    return self;
  } else {
    return nil;
  }
}

- (BOOL)terminal {
  [self getRoot];
  [self.app terminate];
  return YES;
}

- (BOOL)waitUntilSnapshotIsStable
{
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [[XCAXClient_iOS sharedClient] notifyWhenNoAnimationsAreActiveForApplication:self.app reply:^{dispatch_semaphore_signal(sem);}];
  dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC));
  BOOL result = 0 == dispatch_semaphore_wait(sem, timeout);
  return result;
}

- (XCElementSnapshot *)getRoot {
  [self waitUntilSnapshotIsStable];
  XCAccessibilityElement *activeApplicationElement = [[[XCAXClient_iOS sharedClient] activeApplications] firstObject];
  if ([XCUIApplication respondsToSelector:@selector(appWithPID:)]) {
    self.app = [XCUIApplication appWithPID:activeApplicationElement.processIdentifier];
  } else {
    self.app = [XCUIApplication applicationWithPID:activeApplicationElement.processIdentifier];
  }
  [self.app query];
  [self.app resolve];
  
  NSLog(@"%@", ((XCElementSnapshot *)[self.app lastSnapshot]).label);
  return [self.app lastSnapshot];
}

- (NSDictionary *)getTree {
  XCElementSnapshot *root = [self getRoot];
  return [self dictionaryForElement:root withPath:nil withIndex:0 withTypeIndex:0 withCallback:nil];
}

- (NSDictionary *)dictionaryForElement:(XCElementSnapshot *)snapshot
                              withPath:(NSArray *)path
                             withIndex:(NSInteger)index
                         withTypeIndex:(NSInteger)typeIndex
                          withCallback:(BOOL(^)(NSArray *, XCElementSnapshot *))callback {
  NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
  BOOL callbackResult = YES;
  info[@"index"] = [NSNumber numberWithInteger:index];
  info[@"typeIndex"] = [NSNumber numberWithInteger:typeIndex];
  info[@"type"] = [self getElementTypeStringById:snapshot.elementType];
  info[@"label"] = snapshot.label;
  info[@"value"] = snapshot.value;
  info[@"rect"] = @{
                    @"x": [NSNumber numberWithDouble:snapshot.frame.origin.x],
                    @"y": [NSNumber numberWithDouble:snapshot.frame.origin.y],
                    @"width": [NSNumber numberWithDouble:snapshot.frame.size.width],
                    @"height": [NSNumber numberWithDouble:snapshot.frame.size.height]
                    };
  info[@"isVisible"] = [@([snapshot isWDVisible]) stringValue];
  NSMutableArray *currentPath = nil;
  if (path != nil) {
    currentPath = [[NSMutableArray alloc] initWithArray:path];
    [currentPath addObject:info];
    if (callback) {
      callbackResult = callback(currentPath, snapshot);
    }
  }
  NSArray *childElements = snapshot.children;
  if (callbackResult && [childElements count]) {
    info[@"children"] = [[NSMutableArray alloc] init];
    NSMutableDictionary *typeIndexs = [[NSMutableDictionary alloc] init];
    NSInteger i = 0;
    for (XCElementSnapshot *childSnapshot in childElements) {
      NSString *type = [self getElementTypeStringById:childSnapshot.elementType];
      if (typeIndexs[type]) {
        typeIndexs[type] = [NSNumber numberWithInteger:([typeIndexs[type] integerValue] + 1)] ;
      } else {
        typeIndexs[type] = [NSNumber numberWithInteger:0];
      }
      NSDictionary *child = [self dictionaryForElement:childSnapshot
                        withPath:currentPath
                       withIndex:i
                   withTypeIndex:[typeIndexs[type] integerValue]
                    withCallback:callback];
       [info[@"children"] addObject:child];
      i += 1;
    }
  }
  return info;
}

- (CGFloat)compareNode:(NSDictionary *)replayNode withCurrentNode:(NSDictionary *)currentNode {
  CGFloat score = 0.0f;
  if ([replayNode[@"type"] isEqualToString:(NSString *)currentNode[@"type"]]) {
    score += 100.0f;
  } else {
    score -= 100.0f;
  }
  if ([replayNode[@"index"] integerValue] == [currentNode[@"index"] integerValue]) {
    score += 10.0f;
  } else {
    score -= 5.0f;
  }
  if ([replayNode[@"typeIndex"] integerValue] == [currentNode[@"typeIndex"] integerValue]) {
    score += 10.0f;
  } else {
    score -= 5.0f;
  }
  if (replayNode[@"label"] != (id)[NSNull null]) {
    if ([replayNode[@"label"] isEqualToString:(NSString *)currentNode[@"label"]]) {
      if ([replayNode[@"label"] isEqualToString:@""] == NO) {
        score += 100.0f;
      }
    } else {
      score -= 50.0f;
    }
  }
  return score;
}

- (NSDictionary *)matchPath:(NSArray *)path withRoot:(XCElementSnapshot *)root {
  __block CGFloat maxScore = 0.0f;
  __block NSArray *matchPath = nil;
  __block XCElementSnapshot *matchNode = nil;
  [self dictionaryForElement:root withPath:@[] withIndex:0 withTypeIndex:0 withCallback:^BOOL(NSArray *currentPath, XCElementSnapshot *node) {
    if ([currentPath count] == [path count]) {
      CGFloat score = 0.0f;
      for (NSUInteger i = 0; i < [currentPath count]; i++) {
        score = score / 2.0f;
        score += [self compareNode:[path objectAtIndex:i] withCurrentNode:[currentPath objectAtIndex:i]];
      }
      if (score > maxScore) {
        maxScore = score;
        matchPath = currentPath;
        matchNode = node;
      }
      return NO;
    }
    return YES;
  }];
  if (matchPath != nil) {
    return [matchPath lastObject];
  } else {
    return nil;
  }
}

- (CGPoint)relativePointFromNode:(NSDictionary *)node
                    withPosition:(NSDictionary *)position {
  CGRect rect = CGRectMake([node[@"rect"][@"x"] doubleValue], [node[@"rect"][@"y"] doubleValue],
                           [node[@"rect"][@"width"] doubleValue], [node[@"rect"][@"height"] doubleValue]);
  CGPoint point = CGPointMake(rect.origin.x + rect.size.width * [position[@"x"] doubleValue],
                              rect.origin.y + rect.size.height * [position[@"y"] doubleValue]);
  return point;
  
}

- (BOOL)dragFromPoint:(NSDictionary *)startPoint toPoint:(NSDictionary *)endPoint withTrace:(NSArray *)trace {
  XCElementSnapshot *root = [self getRoot];
  NSArray *startPath = [startPoint objectForKey:@"path"];
  NSDictionary *startNode = [self matchPath:startPath withRoot:root];
  NSArray *endPath = [endPoint objectForKey:@"path"];
  NSDictionary *endNode = [self matchPath:endPath withRoot:root];
  if ((startNode != nil) && (endNode != nil)) {
    NSMutableArray *realPath = [[NSMutableArray alloc] init];
    CGPoint realStartPoint = [self relativePointFromNode:startNode withPosition:[startPoint objectForKey:@"position"]];
    //CGPoint realEndPoint = [self relativePointFromNode:endNode withPosition:[endPoint objectForKey:@"position"]];
    [realPath addObject:[[NSDictionary alloc] initWithObjectsAndKeys:
                         [NSNumber numberWithDouble:realStartPoint.x], @"x",
                         [NSNumber numberWithDouble:realStartPoint.y], @"y",
                         nil]];
    for (unsigned int i = 1; i < [trace count]; i++) {
      [realPath addObject:[[NSDictionary alloc] initWithObjectsAndKeys:
                           [NSNumber numberWithDouble:[trace[i][@"x"] doubleValue] * root.frame.size.width], @"x",
                           [NSNumber numberWithDouble:[trace[i][@"y"] doubleValue] * root.frame.size.height], @"y",
                           trace[i][@"offset"], @"offset",
                           nil]];
    }
    [[XCUIDevice sharedDevice] mtc_drag_path:realPath];
    return YES;
  } else {
    return NO;
  }
}

- (BOOL)tapAtPoint:(NSDictionary *)point {
  NSArray *path = [point objectForKey:@"path"];
  XCElementSnapshot *root = [self getRoot];
  NSDictionary *node = [self matchPath:path withRoot:root];
  if (node != nil) {
    if ([node[@"isVisible"] isEqualToString:@"1"]) {
      CGPoint realPoint = [self relativePointFromNode:node withPosition:[point objectForKey:@"position"]];
      [[XCUIDevice sharedDevice] mtc_tap:realPoint];
      return YES;
    } else {
      [self scrollToVisable:point];
      XCElementSnapshot *root2 = [self getRoot];
      NSDictionary *node2 = [self matchPath:path withRoot:root2];
      if (node2 != nil) {
        if ([node2[@"isVisible"] isEqualToString:@"1"]) {
          CGPoint realPoint = [self relativePointFromNode:node2 withPosition:[point objectForKey:@"position"]];
          [[XCUIDevice sharedDevice] mtc_tap:realPoint];
          return YES;
        }
      }
      self.lastError = [NSError errorWithDomain:XCUIReplayHelperErrorDomain code:XCUIReplayHelperErrorCodeNodeNotVisable userInfo:nil];
      return NO;
    }
  } else {
    self.lastError = [NSError errorWithDomain:XCUIReplayHelperErrorDomain code:XCUIReplayHelperErrorCodeNodeNotExists userInfo:nil];
    return NO;
  }
}

- (BOOL)scrollToVisable:(NSDictionary *)point {
  NSArray *path = [point objectForKey:@"path"];
  for (NSInteger i = [path count] - 1; i > 0; i -= 1) {
    NSDictionary *node = [path objectAtIndex:i];
    if ([node[@"type"] isEqualToString:@"Cell"]) {
      NSDictionary *table = [path objectAtIndex:i - 1];
      if ([table[@"type"] isEqualToString:@"Table"]) {
        if (node[@"rect"][@"y"] < table[@"rect"][@"y"]) {
          NSLog(@"try swipe up");
          [[XCUIDevice sharedDevice] mtc_swipe_up];
        } else {
          NSLog(@"try swipe down");
          [[XCUIDevice sharedDevice] mtc_swipe_down];
        }
        return YES;
      }
    }
  }
  return NO;
}

- (BOOL)longtapAtPoint:(NSDictionary *)point {
  NSArray *path = [point objectForKey:@"path"];
  XCElementSnapshot *root = [self getRoot];
  NSDictionary *node = [self matchPath:path withRoot:root];
  if (node != nil) {
    CGPoint realPoint = [self relativePointFromNode:node withPosition:[point objectForKey:@"position"]];
    [[XCUIDevice sharedDevice] mtc_longtap:realPoint duration:2.0f];
    return YES;
  } else {
    return NO;
  }
}

- (BOOL)home {
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
  return YES;
}

- (BOOL)volumeup {
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonVolumeUp];
  return YES;
}

- (BOOL)volumedown {
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonVolumeDown];
  return YES;
}

- (BOOL)sendkey:(NSInteger)asciiCode {
  NSString *string = [NSString stringWithFormat:@"%C", (unichar)asciiCode];
  id<XCTestManager_ManagerInterface> proxy;
  if ([[XCTestDriver sharedTestDriver] respondsToSelector:@selector(managerProxy)]) {
    proxy = [XCTestDriver sharedTestDriver].managerProxy;
  }
  Class runnerClass = objc_lookUpClass("XCTRunnerDaemonSession");
  proxy = ((XCTRunnerDaemonSession *)[runnerClass sharedSession]).daemonProxy;
  [proxy _XCT_sendString:string maximumFrequency:60 completion:^(NSError *typingError){
    
  }];
  return YES;
}

- (BOOL)sendstring:(NSString *)value {
  id<XCTestManager_ManagerInterface> proxy;
  if ([[XCTestDriver sharedTestDriver] respondsToSelector:@selector(managerProxy)]) {
    proxy = [XCTestDriver sharedTestDriver].managerProxy;
  }
  Class runnerClass = objc_lookUpClass("XCTRunnerDaemonSession");
  proxy = ((XCTRunnerDaemonSession *)[runnerClass sharedSession]).daemonProxy;
  [proxy _XCT_sendString:value maximumFrequency:60 completion:^(NSError *typingError){
    
  }];
  return YES;
}

- (BOOL)assertElement:(NSDictionary *)point withValue:(NSString *)value {
  NSArray *path = [point objectForKey:@"path"];
  XCElementSnapshot *root = [self getRoot];
  NSDictionary *node = [self matchPath:path withRoot:root];
  if (node != nil) {
    NSLog(@"%@", value);
    NSLog(@"%@", node );
    if (value != nil) {
      if ([node[@"value"] isEqualToString:value]) {
        return YES;
      } else {
        return NO;
      }
    }
    return YES;
  } else {
    return NO;
  }
}

- (BOOL)runApp:(NSString *)app {
  [[XCUIDevice sharedDevice] openApplicationWithBundleID:app];
  return YES;
}

- (BOOL)replayAction:(NSDictionary *)action {
  NSLog(@"action: %@", action[@"description"]);
  self.lastError = nil;
  BOOL actionRet = NO;
  for (NSInteger i = 0; (actionRet == NO) && (i < 3); i++) {
    [NSThread sleepForTimeInterval:(1.0f * i)];
    if ([[action objectForKey:@"type"] isEqualToString:@"tap"]) {
      actionRet = [self tapAtPoint:[action objectForKey:@"point"]];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"longtap"]) {
      actionRet = [self longtapAtPoint:[action objectForKey:@"point"]];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"dragpath"]) {
      actionRet = [self dragFromPoint:[action objectForKey:@"start"]
                              toPoint:[action objectForKey:@"end"]
                            withTrace:[action objectForKey:@"trace"]];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"home"]) {
      actionRet = [self home];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"volumeup"]) {
      actionRet = [self volumeup];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"volumedown"]) {
      actionRet = [self volumedown];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"sendkey"]) {
      actionRet = [self sendkey:[[action objectForKey:@"key"] integerValue]];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"sendstring"]) {
      actionRet = [self sendstring:[action objectForKey:@"value"]];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"assert"]) {
      actionRet = [self assertElement:[action objectForKey:@"point"] withValue:[action objectForKey:@"value"]];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"run"]) {
      actionRet = [self runApp:[action objectForKey:@"app"]];
    } else if ([[action objectForKey:@"type"] isEqualToString:@"terminal"]) {
      actionRet = [self terminal];
    } else {
      NSLog(@"unknow action type: %@", [action objectForKey:@"type"]);
      break;
    }
  }
  return actionRet;
}

- (BOOL)replayActions:(NSDictionary *)script {
  self.script = script;
  NSArray *lists = [script objectForKey:@"lists"];
  [NSThread sleepForTimeInterval:5.0f];
  for (NSDictionary *list in lists) {
    CGFloat offset = [list[@"offset"] floatValue];
    [NSThread sleepForTimeInterval:offset];
    if ([self replayAction:list]) {
      NSLog(@"success");
    } else {
      NSLog(@"error");
      return NO;
    }
    
  }
  return YES;
}

- (NSString *)getElementTypeStringById:(XCUIElementType)typeId {
  NSDictionary *dict = @{
                         @0 : @"Any",
                         @1 : @"Other",
                         @2 : @"Application",
                         @3 : @"Group",
                         @4 : @"Window",
                         @5 : @"Sheet",
                         @6 : @"Drawer",
                         @7 : @"Alert",
                         @8 : @"Dialog",
                         @9 : @"Button",
                         @10 : @"RadioButton",
                         @11 : @"RadioGroup",
                         @12 : @"CheckBox",
                         @13 : @"DisclosureTriangle",
                         @14 : @"PopUpButton",
                         @15 : @"ComboBox",
                         @16 : @"MenuButton",
                         @17 : @"ToolbarButton",
                         @18 : @"Popover",
                         @19 : @"Keyboard",
                         @20 : @"Key",
                         @21 : @"NavigationBar",
                         @22 : @"TabBar",
                         @23 : @"TabGroup",
                         @24 : @"Toolbar",
                         @25 : @"StatusBar",
                         @26 : @"Table",
                         @27 : @"TableRow",
                         @28 : @"TableColumn",
                         @29 : @"Outline",
                         @30 : @"OutlineRow",
                         @31 : @"Browser",
                         @32 : @"CollectionView",
                         @33 : @"Slider",
                         @34 : @"PageIndicator",
                         @35 : @"ProgressIndicator",
                         @36 : @"ActivityIndicator",
                         @37 : @"SegmentedControl",
                         @38 : @"Picker",
                         @39 : @"PickerWheel",
                         @40 : @"Switch",
                         @41 : @"Toggle",
                         @42 : @"Link",
                         @43 : @"Image",
                         @44 : @"Icon",
                         @45 : @"SearchField",
                         @46 : @"ScrollView",
                         @47 : @"ScrollBar",
                         @48 : @"StaticText",
                         @49 : @"TextField",
                         @50 : @"SecureTextField",
                         @51 : @"DatePicker",
                         @52 : @"TextView",
                         @53 : @"Menu",
                         @54 : @"MenuItem",
                         @55 : @"MenuBar",
                         @56 : @"MenuBarItem",
                         @57 : @"Map",
                         @58 : @"WebView",
                         @59 : @"IncrementArrow",
                         @60 : @"DecrementArrow",
                         @61 : @"Timeline",
                         @62 : @"RatingIndicator",
                         @63 : @"ValueIndicator",
                         @64 : @"SplitGroup",
                         @65 : @"Splitter",
                         @66 : @"RelevanceIndicator",
                         @67 : @"ColorWell",
                         @68 : @"HelpTag",
                         @69 : @"Matte",
                         @70 : @"DockItem",
                         @71 : @"Ruler",
                         @72 : @"RulerMarker",
                         @73 : @"Grid",
                         @74 : @"LevelIndicator",
                         @75 : @"Cell",
                         @76 : @"LayoutArea",
                         @77 : @"LayoutItem",
                         @78 : @"Handle",
                         @79 : @"Stepper",
                         @80 : @"Tab",
                         };
  return [dict objectForKey:[NSNumber numberWithInteger:typeId]];
}

@end


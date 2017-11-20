/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "MTCCustomCommands.h"

#import <XCTest/XCUIDevice.h>

#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBExceptionHandler.h"
#import "FBKeyboard.h"
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "FBSpringboardApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIDevice+MTCTap.h"
#import "XCUIDevice.h"
#import "XCUIElement.h"
#import "XCUIElementQuery.h"

#import "FBElementCommands.h"


#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
#import "XCTestDriver.h"

#import "XCAXClient_iOS.h"
#import "FBSpringboardApplication.h"
#import "XCElementSnapshot.h"
#import "FBElementTypeTransformer.h"
#import "FBMacros.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCAccessibilityElement.h"

#import "XCUIDevice+Usage.h"
#import "XCUIDevice+MTCAppHelper.h"


#import "XCUIReplayHelper.h"

#import "XCTRunnerDaemonSession.h"
#import <objc/runtime.h>

@implementation MTCCustomCommands

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/homescreen"].withoutSession respondWithTarget:self action:@selector(handleHomescreenCommand:)],
    [[FBRoute POST:@"/home"].withoutSession respondWithTarget:self action:@selector(handleHomeCommand:)],
    [[FBRoute POST:@"/homeHold"].withoutSession respondWithTarget:self action:@selector(handleHomeHoldCommand:)],
    [[FBRoute POST:@"/lock"].withoutSession respondWithTarget:self action:@selector(handleLockCommand:)],
    [[FBRoute POST:@"/doubleHome"].withoutSession respondWithTarget:self action:@selector(handleDoubleHomeCommand:)],
    #if !(TARGET_OS_SIMULATOR)
    [[FBRoute POST:@"/volumeup"].withoutSession respondWithTarget:self action:@selector(handleVolumeUpCommand:)],
    [[FBRoute POST:@"/volumedown"].withoutSession respondWithTarget:self action:@selector(handleVolumeDownCommand:)],
    #endif
    
    [[FBRoute POST:@"/run"].withoutSession respondWithTarget:self action:@selector(handleRunCommand:)],
    
    [[FBRoute POST:@"/pasteboard"].withoutSession respondWithTarget:self action:@selector(handleSetPasteBoardCommand:)],
    
    [[FBRoute POST:@"/monkey"].withoutSession respondWithTarget:self action:@selector(handleMonkeyCommand:)],
    
    [[FBRoute POST:@"/tap"].withoutSession respondWithTarget:self action:@selector(handleTapWithoutElement:)],
    [[FBRoute POST:@"/drag"].withoutSession respondWithTarget:self action:@selector(handleDragWithoutSession:)],
    [[FBRoute POST:@"/dragpath"].withoutSession respondWithTarget:self action:@selector(handleDragPathWithoutSession:)],
    [[FBRoute POST:@"/touchAndHold"].withoutSession respondWithTarget:self action:@selector(handleTouchAndHoldCoordinateWithoutSession:)],
    [[FBRoute POST:@"/keys"].withoutSession respondWithTarget:self action:@selector(handleKeys:)],

    [[FBRoute POST:@"/action"].withoutSession respondWithTarget:self action:@selector(handleActionCommand:)],
    [[FBRoute POST:@"/terminal"].withoutSession respondWithTarget:self action:@selector(handleTerminalCommand:)],

    [[FBRoute GET:@"/test"].withoutSession respondWithTarget:self action:@selector(handleTestCommand:)],
    [[FBRoute GET:@"/tree"].withoutSession respondWithTarget:self action:@selector(handleTreeCommand:)],

    [[FBRoute GET:@"/usage"].withoutSession respondWithTarget:self action:@selector(handleUsageCommand:)],
    
    [[FBRoute GET:@"/orientation"].withoutSession respondWithTarget:self action:@selector(handleGetRotation:)],
    [[FBRoute POST:@"/orientation"].withoutSession respondWithTarget:self action:@selector(handleSetRotation:)],
    [[FBRoute GET:@"/test2"].withoutSession respondWithTarget:self action:@selector(handleTest:)],

  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleTest:(FBRouteRequest *)request
{
  NSDictionary *script = request.arguments[@"script"];
  XCUIReplayHelper *replayHelper = [[XCUIReplayHelper alloc] initWithApp:nil];
  [replayHelper replayAction:script];
  
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTreeCommand:(FBRouteRequest *)request
{
  XCUIReplayHelper *helper = [[XCUIReplayHelper alloc] init];
  return FBResponseWithObject([helper getTree]);
}

+ (id<FBResponsePayload>)handleTerminalCommand:(FBRouteRequest *)request
{
  XCUIReplayHelper *helper = [[XCUIReplayHelper alloc] init];
  [helper terminal];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleActionCommand:(FBRouteRequest *)request
{
  NSDictionary *action = request.arguments[@"action"];
  XCUIReplayHelper *replayHelper = [[XCUIReplayHelper alloc] initWithApp:nil];
  BOOL ret = [replayHelper replayAction:action];
  if (ret) {
    return FBResponseWithOK();
  } else {
    return FBResponseWithError(replayHelper.lastError);
  }
}

+ (id<FBResponsePayload>)handleSetRotation:(FBRouteRequest *)request
{
  NSString *newOrientation = request.arguments[@"orientation"] ? request.arguments[@"orientation"] : @"portrait";
  NSLog(@"set Orientation string: %@", newOrientation);
  UIDeviceOrientation orientation = UIDeviceOrientationPortrait;
  if ([newOrientation isEqualToString:@"left"]) {
    orientation = UIDeviceOrientationLandscapeLeft;
  }
  if ([newOrientation isEqualToString:@"right"]) {
    orientation = UIDeviceOrientationLandscapeRight;
  }
  if ([newOrientation isEqualToString:@"down"]) {
    orientation = UIDeviceOrientationPortraitUpsideDown;
  }
  [XCUIDevice sharedDevice].orientation = orientation;
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetRotation:(FBRouteRequest *)request
{
  FBApplication *app = [FBApplication fb_activeApplication];
  UIInterfaceOrientation orientation = app.interfaceOrientation;
  NSString *currentOrientation = @"up";
  if (orientation == UIDeviceOrientationLandscapeLeft) {
    currentOrientation = @"left";
  }
  if (orientation == UIDeviceOrientationLandscapeRight) {
    currentOrientation = @"right";
  }
  if (orientation == UIDeviceOrientationPortraitUpsideDown) {
    currentOrientation = @"down";
  }
  return FBResponseWithObject(@{@"orientation": currentOrientation});
}


+ (id<FBResponsePayload>)handleHomescreenCommand:(FBRouteRequest *)request
{
    NSError *error;
    if (![[XCUIDevice sharedDevice] fb_goToHomescreenWithError:&error]) {
        return FBResponseWithError(error);
    }
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleLockCommand:(FBRouteRequest *)request
{
    [[XCUIDevice sharedDevice] pressLockButton];
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDoubleHomeCommand:(FBRouteRequest *)request
{
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleHomeHoldCommand:(FBRouteRequest *)request
{
    [[XCUIDevice sharedDevice] holdHomeButtonForDuration:3.0f];
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleHomeCommand:(FBRouteRequest *)request
{
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    return FBResponseWithOK();
}

#if !(TARGET_OS_SIMULATOR)
+ (id<FBResponsePayload>)handleVolumeUpCommand:(FBRouteRequest *)request
{
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonVolumeUp];
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleVolumeDownCommand:(FBRouteRequest *)request
{
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonVolumeDown];
    return FBResponseWithOK();
}
#endif

+ (id<FBResponsePayload>)handleRunCommand:(FBRouteRequest *)request
{
    NSString *app = request.arguments[@"app"];
    [[XCUIDevice sharedDevice] openApplicationWithBundleID:app];
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleSetPasteBoardCommand:(FBRouteRequest *)request
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSString *type = request.arguments[@"type"] ? request.arguments[@"type"] : @"string";
    NSString *data = request.arguments[@"data"];
    if ([type isEqualToString:@"string"]) {
        [pasteboard setString:data];
        NSLog(@"set pasteboard string: %@", data);
    }
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleMonkeyCommand:(FBRouteRequest *)request
{
    NSString *action = request.arguments[@"action"] ? request.arguments[@"action"] : @"start";
    int count = request.arguments[@"count"] ? (int)[request.arguments[@"count"] intValue] : 30;
    NSLog(@"monkey: %@, count: %d", action, count);
    if ([action isEqualToString:@"end"]) {
        [[XCUIDevice sharedDevice] mtc_monkey_end];
    } else {
        [[XCUIDevice sharedDevice] mtc_monkey_start_with_limit_count:count];
    }
    return FBResponseWithOK();
}

+ (NSArray *)dictionaryForElement:(XCElementSnapshot *)snapshot
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    info[@"type"] = [FBElementTypeTransformer shortStringWithElementType:snapshot.elementType];
    info[@"name"] = FBValueOrNull(snapshot.wdName);
    info[@"value"] = FBValueOrNull(snapshot.wdValue);
    info[@"label"] = FBValueOrNull(snapshot.wdLabel);
    info[@"rect"] = snapshot.wdRect;
    info[@"isEnabled"] = [@([snapshot isWDEnabled]) stringValue];
    info[@"isVisible"] = [@([snapshot isWDVisible]) stringValue];
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


+ (id<FBResponsePayload>)handleTestCommand:(FBRouteRequest *)request
{

    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleUsageCommand:(FBRouteRequest *)request
{
    return FBResponseWithObject(@{
        @"cpu": [NSNumber numberWithDouble:[[XCUIDevice sharedDevice] CPUUsage]],
        @"memory": [[XCUIDevice sharedDevice] MemoryUsage],
        @"battery": [NSNumber numberWithDouble:[[XCUIDevice sharedDevice] BatteryUsage]],
                                  });
}


+ (id<FBResponsePayload>)handleTapWithoutElement:(FBRouteRequest *)request
{
    CGFloat x = (CGFloat)[request.arguments[@"x"] doubleValue];
    CGFloat y = (CGFloat)[request.arguments[@"y"] doubleValue];
    CGPoint hitPoint = CGPointMake(x, y);
    [[XCUIDevice sharedDevice] mtc_tap:hitPoint];
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDragWithoutSession:(FBRouteRequest *)request
{
  CGPoint startPoint = CGPointMake((CGFloat)[request.arguments[@"fromX"] doubleValue], (CGFloat)[request.arguments[@"fromY"] doubleValue]);
  CGPoint endPoint = CGPointMake((CGFloat)[request.arguments[@"toX"] doubleValue], (CGFloat)[request.arguments[@"toY"] doubleValue]);
  [[XCUIDevice sharedDevice] mtc_drag:startPoint to:endPoint];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDragPathWithoutSession:(FBRouteRequest *)request
{
  NSArray *path = request.arguments[@"path"];
  [[XCUIDevice sharedDevice] mtc_drag_path:path];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTouchAndHoldCoordinateWithoutSession:(FBRouteRequest *)request
{
    CGFloat x = (CGFloat)[request.arguments[@"x"] doubleValue];
    CGFloat y = (CGFloat)[request.arguments[@"y"] doubleValue];
    CGFloat duration = (CGFloat)[request.arguments[@"duration"] doubleValue];
    CGPoint hitPoint = CGPointMake(x, y);
    [[XCUIDevice sharedDevice] mtc_longtap:hitPoint duration:duration];
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleKeys:(FBRouteRequest *)request
{
    NSString *textToType = request.arguments[@"value"];
    NSLog(@"type %@", textToType);
    id<XCTestManager_ManagerInterface> proxy = nil;
    if ([[XCTestDriver sharedTestDriver] respondsToSelector:@selector(managerProxy)]) {
        proxy = [XCTestDriver sharedTestDriver].managerProxy;
    } else {
        Class runnerClass = objc_lookUpClass("XCTRunnerDaemonSession");
        proxy = ((XCTRunnerDaemonSession *)[runnerClass sharedSession]).daemonProxy;
    }
    [proxy _XCT_sendString:textToType maximumFrequency:60 completion:^(NSError *typingError){
        if (typingError) {
            NSLog(@"%@", typingError);
        }
    }];
    return FBResponseWithOK();
}

@end

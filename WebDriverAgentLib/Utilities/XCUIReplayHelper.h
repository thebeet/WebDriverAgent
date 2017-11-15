//
//  XCUIReplayHelper.h
//  XCUITestWrap
//
//  Created by 项光特 on 04/09/2017.
//  Copyright © 2017 项光特. All rights reserved.
//

#ifndef XCUIReplayHelper_h
#define XCUIReplayHelper_h

#import "XCUIApplication.h"

static NSString *const XCUIReplayHelperErrorDomain = @"com.baidu.mtc.xcuireplayhelper";
typedef NS_ENUM(NSInteger, XCUIReplayHelperErrorCode){
  XCUIReplayHelperErrorCodeNodeNotExists,
  XCUIReplayHelperErrorCodeNodeNotVisable,
  XCUIReplayHelperErrorCodeNodeNotOther
};

@interface XCUIReplayHelper : NSObject

- (id)initWithApp:(XCUIApplication *)app;
- (id)init;
- (NSDictionary *)getTree;
- (BOOL)replayAction:(NSDictionary *)action;
- (BOOL)scrollToVisable:(NSDictionary *)point;
- (BOOL)terminal;

@property XCUIApplication *app;
@property NSDictionary *script;
@property NSError *lastError;

@end

#endif /* XCUIReplayHelper_h */


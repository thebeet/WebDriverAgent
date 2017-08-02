//
//  XCUIDevice_XCUIDevice_MTCAppHelper.h
//  WebDriverAgent
//
//  Created by 项光特 on 2017/3/24.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface XCUIDevice (MTCAppHelper)

- (void)openApplicationWithBundleID: (NSString *)bundleID;

@end

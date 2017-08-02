//
//  XCUIDevice+Usage.h
//  WebDriverAgent
//
//  Created by 项光特 on 2017/3/15.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#ifndef XCUIDevice_Usage_h
#define XCUIDevice_Usage_h

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN


@interface XCUIDevice (Usage)

- (double)CPUUsage;
- (NSDictionary *)MemoryUsage;
- (double)BatteryUsage;

@end

NS_ASSUME_NONNULL_END

#endif /* XCUIDevice_Usage_h */

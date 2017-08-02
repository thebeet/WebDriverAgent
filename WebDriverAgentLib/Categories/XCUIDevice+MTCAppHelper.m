//
//  XCUIDevice+MTCAppHelper.m
//  WebDriverAgent
//
//  Created by 项光特 on 2017/3/24.
//

#import "XCUIDevice+MTCAppHelper.h"

#import <objc/runtime.h>

@implementation XCUIDevice (MTCAppHelper)

- (void)openApplicationWithBundleID: (NSString *)bundleID {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    Class LSAppClass = objc_getClass("LSApplicationWorkspace");
    NSObject *workspace = [LSAppClass performSelector:NSSelectorFromString(@"defaultWorkspace")];
    [workspace performSelector:NSSelectorFromString(@"openApplicationWithBundleID:") withObject:bundleID] ;
#pragma clang diagnostic pop
}


@end

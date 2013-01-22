//
//  NSObject+MiscHelpers.h
//  NetflixQual
//
//  Created by William Lindmeier on 9/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define IS_IPAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

@interface NSObject(MiscHelpers)
@end

@interface NSString(MiscHelpers)

- (BOOL)isNotBlank;
+ (NSDictionary *)dictionaryFromQueryParams:(NSString *)paramsString lowercaseKeys:(BOOL)shouldLowercase;
+ (NSString *)createGUID;

@end

@interface NSArray(MiscHelpers)

- (NSArray *)reversedArray;

@end

@interface UIView(MiscHelpers)

- (UIImage *)renderedAsImage;
- (CGPoint)positionWithinView:(UIView *)parentView;
- (CGRect)frameWithinView:(UIView *)parentView;

- (void)setFrameX:(float)newX;
- (void)setFrameY:(float)newY;
- (void)setFrameWidth:(float)newWidth;
- (void)setFrameHeight:(float)newHeight;
- (void)roundFrame;

@end

#   if DEBUG == 1
#       define NSLogDebug(format, ...) NSLog(@"%@", [NSString stringWithFormat:format, ## __VA_ARGS__])
#   else
#       define NSLogDebug(...) ((void)0)
#   endif

static inline void LogNotification (CFNotificationCenterRef center,
                                    void *observer,
                                    CFStringRef name,
                                    const void *object,
                                    CFDictionaryRef userInfo)
{
    NSLogDebug(@"NOTIFICATION SENT. name: %@", name);
    //NSLogDebug(@"userinfo: %@", userInfo);
}
/*
 
 // TO USE:
 BOOL logNSNotifications = YES;
 if(logNSNotifications){
 CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), 
 NULL, 
 LogNotification, 
 NULL, 
 NULL,  
 CFNotificationSuspensionBehaviorDeliverImmediately);
 }
 */

@interface CALayer(MiscHelpers)

- (void)pause;
- (void)resume;
- (void)changeSpeed:(float)newSpeed;

@end

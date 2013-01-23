//
//  WDLSettingsManager.h
//  ABSeeCrew
//
//  Created by William Lindmeier on 5/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const WDLSettingsKeyHueStart;
extern NSString *const WDLSettingsKeyHueEnd;
extern NSString *const WDLSettingsKeyValueStart;
extern NSString *const WDLSettingsKeyValueEnd;
extern NSString *const WDLSettingsKeySaturationStart;
extern NSString *const WDLSettingsKeySaturationEnd;
extern NSString *const WDLSettingsKeyMarkerMargin;
extern NSString *const WDLSettingsKeyColorTriggersRecording;
extern NSString *const WDLSettingsKeySelectedCamera;
extern NSString *const WDLSettingsKeyMaxAnimationSecs;
extern NSString *const WDLSettingsKeyRecordingTriggersTorch;

extern NSString *const WDLSettingsDidChangeNotification;

const float MinAnimationDuration = 0.5f;
const float MaxAnimationDuration = 7.0f;
const float AnimationDurationRange = MaxAnimationDuration - MinAnimationDuration;

@interface WDLSettingsManager : NSObject

+ (void)registerDefaults;
+ (id)valueForSetting:(NSString *)settingName;
+ (void)setValue:(NSObject *)value forSetting:(NSString *)settingName;

@end

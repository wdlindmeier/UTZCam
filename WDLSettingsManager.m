//
//  WDLSettingsManager.m
//  ABSeeCrew
//
//  Created by William Lindmeier on 5/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WDLSettingsManager.h"

static NSString *const WDLSettingsDefaultsHaveBeenRegistered = @"WDLSettingsDefaultsHaveBeenRegistered";

NSString *const WDLSettingsKeyHueStart = @"WDLSettingsKeyHueStart";
NSString *const WDLSettingsKeyHueEnd = @"WDLSettingsKeyHueEnd";
NSString *const WDLSettingsKeyValueStart = @"WDLSettingsKeyValueStart";
NSString *const WDLSettingsKeyValueEnd = @"WDLSettingsKeyValueEnd";
NSString *const WDLSettingsKeySaturationStart = @"WDLSettingsKeySaturationStart";
NSString *const WDLSettingsKeySaturationEnd = @"WDLSettingsKeySaturationEnd";
NSString *const WDLSettingsKeyMarkerMargin = @"WDLSettingsKeyMarkerMargin";
NSString *const WDLSettingsKeyColorTriggersRecording = @"WDLSettingsKeyColorTriggersRecording";
NSString *const WDLSettingsKeySelectedCamera = @"WDLSettingsKeySelectedCamera";
NSString *const WDLSettingsKeyMaxAnimationSecs = @"WDLSettingsKeyMaxAnimationSecs";
NSString *const WDLSettingsKeyRecordingTriggersTorch = @"WDLSettingsKeyRecordingTriggersTorch";

NSString *const WDLSettingsDidChangeNotification = @"WDLSettingsDidChangeNotification";

@implementation WDLSettingsManager

+ (void)registerDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];
    BOOL isRegistered = [defaults boolForKey:WDLSettingsDefaultsHaveBeenRegistered];
    if(!isRegistered){
        
        [defaults setBool:YES forKey:WDLSettingsDefaultsHaveBeenRegistered];
        
        // This is calibrated for a Cheeto w/ out the torch
        [defaults setValue:@0 forKey:WDLSettingsKeyHueStart];
        [defaults setValue:@22 forKey:WDLSettingsKeyHueEnd];
        [defaults setValue:@184 forKey:WDLSettingsKeySaturationStart];
        [defaults setValue:@255 forKey:WDLSettingsKeySaturationEnd];
        [defaults setValue:@163 forKey:WDLSettingsKeyValueStart];
        [defaults setValue:@255 forKey:WDLSettingsKeyValueEnd];
        
        [defaults setValue:@0 forKey:WDLSettingsKeySelectedCamera];
        [defaults setValue:@3.0f forKey:WDLSettingsKeyMaxAnimationSecs];

        [defaults setValue:@0.3 forKey:WDLSettingsKeyMarkerMargin];
        
        [defaults setBool:NO forKey:WDLSettingsKeyColorTriggersRecording];
        [defaults setBool:NO forKey:WDLSettingsKeyRecordingTriggersTorch];
        
        [defaults synchronize];
        
    }
}

+ (void)setValue:(NSObject *)value forSetting:(NSString *)settingName
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:settingName];
    [defaults synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:WDLSettingsDidChangeNotification
                                                        object:settingName];
}

+ (id)valueForSetting:(NSString *)settingName
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults valueForKey:settingName];
}

@end

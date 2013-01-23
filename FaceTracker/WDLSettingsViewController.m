//
//  WDLSettingsViewController.m
//  UTZ Cam
//
//  Created by William Lindmeier on 1/23/13.
//
//

#import "WDLSettingsViewController.h"
#import "WDLSettingsManager.h"

@interface WDLSettingsViewController ()

@end

@implementation WDLSettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated
{
    self.switchColorTriggerRecording.on = [[WDLSettingsManager valueForSetting:WDLSettingsKeyColorTriggersRecording] boolValue];
    self.switchRecordingTriggersTorch.on = [[WDLSettingsManager valueForSetting:WDLSettingsKeyRecordingTriggersTorch] boolValue];
    NSNumber *numMaxAnim = [WDLSettingsManager valueForSetting:WDLSettingsKeyMaxAnimationSecs];
    float maxAnimationDuration = [numMaxAnim floatValue];
    self.sliderAnimationDuration.value = (maxAnimationDuration-MinAnimationDuration) / AnimationDurationRange;
    // Update the label
    [self sliderAnimationDurationChanged:nil];
}

#pragma mark - IBAction

- (IBAction)buttonBackPressed:(id)sender
{
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)switchColorTriggerRecordingChanged:(id)sender
{
    [WDLSettingsManager setValue:[NSNumber numberWithBool:self.switchColorTriggerRecording.on]
                      forSetting:WDLSettingsKeyColorTriggersRecording];
}

- (IBAction)switchRecordingTriggersTorchChanged:(id)sender
{
    [WDLSettingsManager setValue:[NSNumber numberWithBool:self.switchRecordingTriggersTorch.on]
                      forSetting:WDLSettingsKeyRecordingTriggersTorch];
}

- (IBAction)sliderAnimationDurationChanged:(id)sender
{
    float newDuration = MinAnimationDuration + (AnimationDurationRange * self.sliderAnimationDuration.value);
    self.labelAnimationDuration.text = [NSString stringWithFormat:@"%0.1f", newDuration];
    [WDLSettingsManager setValue:@(newDuration) forSetting:WDLSettingsKeyMaxAnimationSecs];
}

@end

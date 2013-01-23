//
//  WDLSettingsViewController.h
//  UTZ Cam
//
//  Created by William Lindmeier on 1/23/13.
//
//

#import <UIKit/UIKit.h>

@interface WDLSettingsViewController : UIViewController

@property (nonatomic, strong) IBOutlet UISwitch *switchColorTriggerRecording;
@property (nonatomic, strong) IBOutlet UISwitch *switchRecordingTriggersTorch;
@property (nonatomic, strong) IBOutlet UISlider *sliderAnimationDuration;
@property (nonatomic, strong) IBOutlet UILabel *labelAnimationDuration;

- (IBAction)buttonBackPressed:(id)sender;
- (IBAction)switchColorTriggerRecordingChanged:(id)sender;
- (IBAction)switchRecordingTriggersTorchChanged:(id)sender;
- (IBAction)sliderAnimationDurationChanged:(id)sender;

@end

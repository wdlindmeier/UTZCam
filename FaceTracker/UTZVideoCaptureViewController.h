//
//  UTZVideoCaptureViewController.h
//  UTZ Cam
//
//  Created by William Lindmeier on 1/18/13.
//
//

#import "VideoCaptureViewController.h"
#import <MessageUI/MessageUI.h>

@interface UTZVideoCaptureViewController : VideoCaptureViewController <
MFMailComposeViewControllerDelegate,
UIActionSheetDelegate
>

@property (nonatomic, strong) IBOutlet UIView *viewHUD;
@property (nonatomic, strong) IBOutlet UIView *viewProcessing;
@property (nonatomic, strong) IBOutlet UILabel *labelLoading;

@property (nonatomic, strong) IBOutlet UISlider *sliderHMin;
@property (nonatomic, strong) IBOutlet UISlider *sliderHMax;
@property (nonatomic, strong) IBOutlet UISlider *sliderSMin;
@property (nonatomic, strong) IBOutlet UISlider *sliderSMax;
@property (nonatomic, strong) IBOutlet UISlider *sliderVMin;
@property (nonatomic, strong) IBOutlet UISlider *sliderVMax;

@property (nonatomic, strong) IBOutlet UISlider *sliderFramePadding;

@property (nonatomic, strong) IBOutlet UILabel *labelHMin;
@property (nonatomic, strong) IBOutlet UILabel *labelHMax;
@property (nonatomic, strong) IBOutlet UILabel *labelSMin;
@property (nonatomic, strong) IBOutlet UILabel *labelSMax;
@property (nonatomic, strong) IBOutlet UILabel *labelVMin;
@property (nonatomic, strong) IBOutlet UILabel *labelVMax;

@property (nonatomic, strong) IBOutlet UIButton *buttonPlay;
@property (nonatomic, strong) IBOutlet UIButton *buttonRecord;
@property (nonatomic, strong) IBOutlet UIButton *buttonSave;
@property (nonatomic, strong) IBOutlet UIButton *buttonTorch;
@property (nonatomic, strong) IBOutlet UIButton *buttonFlipCam;
@property (nonatomic, strong) IBOutlet UIButton *buttonColor;
@property (nonatomic, strong) IBOutlet UIButton *buttonSettings;

- (IBAction)sliderColorMoved:(id)sender;
- (IBAction)sliderFramePaddingMoved:(id)sender;
- (IBAction)buttonHUDPressed:(id)sender;
- (IBAction)buttonRecordPressed:(id)sender;
- (IBAction)buttonPlayPressed:(id)sender;
- (IBAction)buttonSavePressed:(id)sender;
- (IBAction)buttonTorchPressed:(id)sender;
- (IBAction)buttonCamFlipPressed:(id)sender;
- (IBAction)buttonSettingsPressed:(id)sender;

@end

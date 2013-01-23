//
//  UTZVideoCaptureViewController.h
//  UTZ Cam
//
//  Created by William Lindmeier on 1/18/13.
//
//

#import "VideoCaptureViewController.h"

@interface UTZVideoCaptureViewController : VideoCaptureViewController /*<
UINavigationControllerDelegate,
UIImagePickerControllerDelegate
>*/

@property (nonatomic, strong) IBOutlet UIView *viewHUD;

@property (nonatomic, strong) IBOutlet UISlider *sliderHMin;
@property (nonatomic, strong) IBOutlet UISlider *sliderHMax;
@property (nonatomic, strong) IBOutlet UISlider *sliderSMin;
@property (nonatomic, strong) IBOutlet UISlider *sliderSMax;
@property (nonatomic, strong) IBOutlet UISlider *sliderVMin;
@property (nonatomic, strong) IBOutlet UISlider *sliderVMax;

@property (nonatomic, strong) IBOutlet UILabel *labelHMin;
@property (nonatomic, strong) IBOutlet UILabel *labelHMax;
@property (nonatomic, strong) IBOutlet UILabel *labelSMin;
@property (nonatomic, strong) IBOutlet UILabel *labelSMax;
@property (nonatomic, strong) IBOutlet UILabel *labelVMin;
@property (nonatomic, strong) IBOutlet UILabel *labelVMax;

@property (nonatomic, strong) IBOutlet UIButton *buttonPlay;
@property (nonatomic, strong) IBOutlet UIButton *buttonRecord;

- (IBAction)sliderMoved:(id)sender;
- (IBAction)buttonHUDPressed:(id)sender;
- (IBAction)buttonRecordPressed:(id)sender;
- (IBAction)buttonPlayPressed:(id)sender;
- (IBAction)buttonGIFPressed:(id)sender;
- (IBAction)buttonTorchPressed:(id)sender;
- (IBAction)buttonCamFlipPressed:(id)sender;


@end

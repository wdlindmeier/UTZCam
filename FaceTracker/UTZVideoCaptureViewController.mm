//
//  UTZVideoCaptureViewController.m
//  UTZ Cam
//
//  Created by William Lindmeier on 1/18/13.
//
//

#import "UTZVideoCaptureViewController.h"
#import "UIImage+OpenCV.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <CoreImage/CoreImage.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIImage+INResizeImageAllocator.h"
#import "CGGeometry.h"
#import "WDLAnimatedGIFView.h"
#import "CGCVHelpers.h"
#import "WDLSettingsViewController.h"
#import "WDLSettingsManager.h"

enum {
    CamBack = 0,
    CamFront = 1
};

typedef enum ViewStates {
    ViewStatePreview,
    ViewStateRecording,
    ViewStatePlayback
} ViewState;

using namespace std;

static const float MaxFrameToMarkerMargin = 5.0f;
static const float MaxFrameDimension = 320.0f;

@interface UTZVideoCaptureViewController ()
{
    BOOL _showsThreshold;
    int _hMin, _hMax, _sMin, _sMax, _vMin, _vMax;
    BOOL _isPlaying;
    BOOL _isRecording;
    WDLAnimatedGIFView *_imgViewAnimation;
    UIInterfaceOrientation _videoOrientation;
    CGRect _cropFramePrev;
    BOOL _isColorPanelDisplayed;
    float _fpsCaptured;
    float _markerMargin;
    BOOL _startRecordingWhenMarkerAppears;
    BOOL _shouldRecordingTriggerTorch;
    BOOL _wasTorchOn;
    ViewStates _currentViewState;
    float _maxAnimationDuration;
}

@property (atomic, strong) NSMutableArray *recordedFrames;
@property (atomic, strong) NSMutableArray *capturedFrames;
@property (atomic, strong) AVAssetReader *assetReader;
@property (atomic, strong) AVAssetReaderTrackOutput * output;
@property (atomic, assign) BOOL isProcessing;

@end

@implementation UTZVideoCaptureViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.captureGrayscale = NO;// YES;
        self.qualityPreset = AVCaptureSessionPresetMedium;
        self.camera = [[WDLSettingsManager valueForSetting:WDLSettingsKeySelectedCamera] intValue]; //CamBack;
        _showsThreshold = NO;
        _isPlaying = NO;
        self.isProcessing = NO;
        _isRecording = NO;
        _isColorPanelDisplayed = NO;
        self.torchOn = NO;
        _wasTorchOn = NO;
        _maxAnimationDuration = [[WDLSettingsManager valueForSetting:WDLSettingsKeyMaxAnimationSecs] floatValue];
        _hMin = [[WDLSettingsManager valueForSetting:WDLSettingsKeyHueStart] floatValue];
        _hMax = [[WDLSettingsManager valueForSetting:WDLSettingsKeyHueEnd] floatValue];
        _sMin = [[WDLSettingsManager valueForSetting:WDLSettingsKeySaturationStart] floatValue];
        _sMax = [[WDLSettingsManager valueForSetting:WDLSettingsKeySaturationEnd] floatValue];
        _vMin = [[WDLSettingsManager valueForSetting:WDLSettingsKeyValueStart] floatValue];
        _vMax = [[WDLSettingsManager valueForSetting:WDLSettingsKeyValueEnd] floatValue];
        
    }
    return self;
}

#pragma mark - Accessors

- (NSString *)tmpGIFPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:@"tmp.gif"];
}

- (void)setCamera:(int)camera
{
    [super setCamera:camera];
    [WDLSettingsManager setValue:@(camera) forSetting:WDLSettingsKeySelectedCamera];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.sliderHMin.value = _hMin / 255.0f;
    self.sliderHMax.value = _hMax / 255.0f;
    self.sliderSMin.value = _sMin / 255.0f;
    self.sliderSMax.value = _sMax / 255.0f;
    self.sliderVMin.value = _vMin / 255.0f;
    self.sliderVMax.value = _vMax / 255.0f;
    
    // Update the labels
    [self sliderColorMoved:nil];
    
    // Update the margin
    self.sliderFramePadding.value = [[WDLSettingsManager valueForSetting:WDLSettingsKeyMarkerMargin] floatValue];
    [self sliderFramePaddingMoved:nil];
    
    [self setViewState:ViewStatePreview];

}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self resumeCapture];
    
    // These values may have changed on the settings page
    _startRecordingWhenMarkerAppears = [[WDLSettingsManager valueForSetting:WDLSettingsKeyColorTriggersRecording] boolValue];
    _shouldRecordingTriggerTorch = [[WDLSettingsManager valueForSetting:WDLSettingsKeyRecordingTriggersTorch] boolValue];
    _maxAnimationDuration = [[WDLSettingsManager valueForSetting:WDLSettingsKeyMaxAnimationSecs] floatValue];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pauseCapture];
}

#pragma mark - Settings

- (void)savePadding
{
    float paddingVal = self.sliderFramePadding.value;
    [WDLSettingsManager setValue:@(paddingVal) forSetting:WDLSettingsKeyMarkerMargin];
}

- (void)saveColors
{
    [WDLSettingsManager setValue:@(_hMin) forSetting:WDLSettingsKeyHueStart];
    [WDLSettingsManager setValue:@(_hMax) forSetting:WDLSettingsKeyHueEnd];
    [WDLSettingsManager setValue:@(_sMin) forSetting:WDLSettingsKeySaturationStart];
    [WDLSettingsManager setValue:@(_sMax) forSetting:WDLSettingsKeySaturationEnd];
    [WDLSettingsManager setValue:@(_vMin) forSetting:WDLSettingsKeyValueStart];
    [WDLSettingsManager setValue:@(_vMax) forSetting:WDLSettingsKeyValueEnd];
}

#pragma mark - IBAction

- (IBAction)buttonTorchPressed:(id)sender
{
    self.torchOn = !self.torchOn;
}

- (IBAction)sliderFramePaddingMoved:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(savePadding) object:nil];
    
    _markerMargin = self.sliderFramePadding.value * MaxFrameToMarkerMargin;
    
    [self performSelector:@selector(savePadding) withObject:nil afterDelay:0.5];
    
}

- (IBAction)sliderColorMoved:(id)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveColors) object:nil];
    
    _hMin = self.sliderHMin.value * 255;
    _hMax = self.sliderHMax.value * 255;
    _sMin = self.sliderSMin.value * 255;
    _sMax = self.sliderSMax.value * 255;
    _vMin = self.sliderVMin.value * 255;
    _vMax = self.sliderVMax.value * 255;

    self.labelHMin.text = [NSString stringWithFormat:@"%i", _hMin];
    self.labelHMax.text = [NSString stringWithFormat:@"%i", _hMax];
    self.labelSMin.text = [NSString stringWithFormat:@"%i", _sMin];
    self.labelSMax.text = [NSString stringWithFormat:@"%i", _sMax];
    self.labelVMin.text = [NSString stringWithFormat:@"%i", _vMin];
    self.labelVMax.text = [NSString stringWithFormat:@"%i", _vMax];
    
    [self performSelector:@selector(saveColors) withObject:nil afterDelay:0.5];
    
}

- (IBAction)buttonHUDPressed:(id)sender
{
    _isColorPanelDisplayed = self.viewHUD.hidden;
    self.viewHUD.hidden = !_isColorPanelDisplayed;
}

- (IBAction)buttonRecordPressed:(id)sender
{
    if(!_isRecording){
        
        [self startRecording];
        
    }else{
        
        // Finish up
        [self stopRecording];
        
    }

}


- (IBAction)buttonPlayPressed:(id)sender
{
    
    if(_isPlaying){
        
        [self stopPlaying];
        
    }else{
        
        // Play
        [self startPlaying];
        
    }
    
    self.buttonRecord.enabled = !_isPlaying;
    
}

static NSString *ActionSheetButtonTitleEmail = NSLocalizedString(@"E-mail", @"Email export gif button");
static NSString *ActionSheetButtonTitlePhotoLibrary = NSLocalizedString(@"Save to Library", @"Photo Roll export gif button");
static NSString *ActionSheetButtonTitleSave = NSLocalizedString(@"Save", @"Save export gif button");

- (IBAction)buttonSavePressed:(id)sender
{
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Export GIF", @"export action sheet title")
                                delegate:self
                       cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel save button")
                  destructiveButtonTitle:nil
                       otherButtonTitles:ActionSheetButtonTitleEmail,
                                         ActionSheetButtonTitlePhotoLibrary,
                                         //ActionSheetButtonTitleSave,
                         nil];
    
    [as showInView:self.view];
    
}

- (IBAction)buttonCamFlipPressed:(id)sender
{
    self.camera = (self.camera == 1) ? 0 : 1;
}

- (IBAction)buttonSettingsPressed:(id)sender
{
    WDLSettingsViewController *settingsVC = [[WDLSettingsViewController alloc] initWithNibName:@"WDLSettingsViewController"
                                                                                        bundle:nil];
    settingsVC.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [self presentViewController:settingsVC animated:YES completion:^{
        //...
    }];
}

#pragma mark - View States

- (void)setViewState:(ViewState)state
{
    
    for(CALayer *l in self.view.layer.sublayers){
        if([l.name isEqualToString:@"BlobRect"] ||  [l.name isEqualToString:@"CaptureRect"]){
            l.hidden = state != ViewStatePreview;
        }else if([l.name isEqualToString:@"Threshold"]){
            l.hidden = state != ViewStatePreview;
        }
    }
    
    [self.buttonRecord.layer removeAllAnimations];

    switch (state) {
        case ViewStateRecording:
            self.buttonSettings.hidden = YES;
            self.buttonPlay.hidden = YES;
            self.buttonRecord.hidden = NO;
            self.buttonSave.hidden = YES;
            self.buttonTorch.hidden = YES;
            self.buttonFlipCam.hidden = YES;
            self.buttonColor.hidden = YES;
            self.viewHUD.hidden = YES;
        {
            CABasicAnimation *animThrob = [CABasicAnimation animationWithKeyPath:@"opacity"];
            animThrob.fromValue = [NSNumber numberWithFloat:1.0];
            animThrob.toValue = [NSNumber numberWithFloat:0.25];
            animThrob.repeatCount = 999;
            animThrob.duration = 0.25;
            animThrob.autoreverses = YES;
            [self.buttonRecord.layer addAnimation:animThrob forKey:@"opacity"];
        }
            break;
        case ViewStatePlayback:
            self.buttonSettings.hidden = NO;
            self.buttonPlay.hidden = NO;
            self.buttonPlay.enabled = YES;
            self.buttonRecord.hidden = YES;
            self.buttonSave.hidden = NO;
            self.buttonTorch.hidden = YES;
            self.buttonFlipCam.hidden = YES;
            self.buttonColor.hidden = YES;
            self.viewHUD.hidden = YES;
            break;
        case ViewStatePreview:
            self.buttonSettings.hidden = NO;
            self.buttonPlay.hidden = NO;
            self.buttonPlay.enabled = self.recordedFrames.count > 0;
            self.buttonRecord.hidden = NO;
            self.buttonSave.hidden = YES;
            self.buttonTorch.hidden = NO;
            self.buttonFlipCam.hidden = NO;
            self.buttonColor.hidden = NO;
            self.viewHUD.hidden = !_isColorPanelDisplayed;
            break;
    }
    
    _currentViewState = state;
}

- (void)startImageViewPlayback
{
    _imgViewAnimation.frame = self.view.bounds;
    _imgViewAnimation.backgroundColor = [UIColor blackColor];
    _imgViewAnimation.contentMode = UIViewContentModeScaleAspectFit;
    [self.view insertSubview:_imgViewAnimation
                belowSubview:self.buttonPlay];
    [_imgViewAnimation startAnimating];
    _isPlaying = YES;
}

- (void)pauseCapture
{
    [_captureSession stopRunning];
}

- (void)resumeCapture
{
    [_captureSession startRunning];
}

- (void)startRecording
{
    if(!_isRecording){
        
        [self setViewState:ViewStateRecording];
        
        _wasTorchOn = self.torchOn;
        if(_shouldRecordingTriggerTorch){
            self.torchOn = YES;
        }
        
        _isRecording = YES;
        
        if(_isPlaying){
            [self stopPlaying];
        }
        
        self.recordedFrames = nil;
        int maxNumFrames = (int)(_maxAnimationDuration * 30);
        self.capturedFrames = [NSMutableArray arrayWithCapacity:maxNumFrames];
        
        // Max animation duration
        [self performSelector:@selector(stopRecording) withObject:nil afterDelay:_maxAnimationDuration];
    }    
}

- (void)stopRecording
{
    if(_isRecording){
        
        self.torchOn = _wasTorchOn;
        _fpsCaptured = _fps;
        _isRecording = NO;
        [self.buttonRecord.layer removeAllAnimations];
        [self processCapturedFrames];

    }
}

- (void)stopPlaying
{
    [_imgViewAnimation removeFromSuperview];
    _imgViewAnimation = nil;
    
    [self setViewState:ViewStatePreview];
    
    [self resumeCapture];
    
    _isPlaying = NO;
}

- (void)startPlaying
{
     if(self.recordedFrames && self.recordedFrames.count > 0){
         
         [self setViewState:ViewStatePlayback];
         
        [self pauseCapture];
        
        if(_imgViewAnimation){
            [_imgViewAnimation removeFromSuperview];
            _imgViewAnimation = nil;
        }
        
        _imgViewAnimation = [[WDLAnimatedGIFView alloc] initWithFrame:self.view.bounds];
        NSArray *imgs = [NSArray arrayWithArray:self.recordedFrames];
        _imgViewAnimation.animationImages = imgs;
        _imgViewAnimation.image = imgs[0];
         // Getting the fps from parent when the recording is complete
        _imgViewAnimation.animationDuration = round(imgs.count / _fpsCaptured);
        _imgViewAnimation.animationRepeatCount = 0; //endless

         // NOTE: This will set _isPlaying = YES
        [self startImageViewPlayback];

    }else{
        
        NSLog(@"ERROR: Couldn't find recorded frames");
        
    }
}

#pragma mark - VideoCaptureViewController overrides

typedef void (^image_proc_block_t)(CGRect rectBlob, UIImage *imgBlob);

- (void)processCVFrame:(cv::Mat &)mat videoRect:(CGRect)rect videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{ /*
- (void)processFrame:(UIImage *)image videoRect:(CGRect)rect videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{*/
    if(_isRecording){
        
        // Just store the image
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            UIImage *imgOutput = [UIImage imageWithCVMat:mat];
            [self.capturedFrames addObject:imgOutput];
            
        });
        
    }else if(!self.isProcessing){
        
        [self processFrame:mat
                 videoRect:rect
                completion:^(CGRect rectBlob, UIImage *imgBlob) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                // TODO: Should this be a setting?
                // This is the threshold for color that is required to trigger
                static const float MinMarkerTriggerSize = 1000.0f;
                
                float rectArea = rectBlob.size.width * rectBlob.size.height;
                
                if(_startRecordingWhenMarkerAppears && rectArea > MinMarkerTriggerSize){

                    [self startRecording];
                    
                }else{
                    // This is a preview. Just show the blobs in a rect.
                    [self displayBlob:rectBlob
                              inImage:imgBlob
                         forVideoRect:rect
                     videoOrientation:AVCaptureVideoOrientationPortrait];
                }
                
            });
        }];
        
    }
}

- (void)processFrame:(cv::Mat &)mat
           videoRect:(CGRect)rect
          completion:(image_proc_block_t)blockComplete
/*
- (void)processFrame:(UIImage *)image
           videoRect:(CGRect)rect
          completion:(image_proc_block_t)blockComplete */
{

    if(CGRectEqualToRect(rect, CGRectZero)){
        blockComplete(CGRectZero, nil);
    }
    
    cv::Mat matSmall = mat;
    //cv::Mat matSmall = [image CVMat];
    
    if (self.camera == 0){
        // flip around y axis for back camera
        cv::flip(matSmall, matSmall, 0); // -1 == both, 0 == x, 1 == y
    }

    // Rotate video frame by 90deg to portrait by combining a transpose and a flip
    // Note that AVCaptureVideoDataOutput connection does NOT support hardware-accelerated
    // rotation and mirroring via videoOrientation and setVideoMirrored properties so we
    // need to do the rotation in software here.

    cv::transpose(matSmall, matSmall);
    CGFloat temp = rect.size.width;
    rect.size.width = rect.size.height;
    rect.size.height = temp;

    // Detect faces
    std::vector<cv::Rect> faces;
    
    // Detect blobs
    // http://www.aishack.in/2010/07/tracking-colored-objects-in-opencv/
    // Durp
    cv::Mat matHSV = cv::Mat(rect.size.width, rect.size.height, CV_8UC1);
    cv::Mat matThresh = cv::Mat(rect.size.width, rect.size.height, CV_8UC1);
    if(self.captureGrayscale){
        NSLog(@"ERROR: Cant track color in gray scale");
        return;
    }
    
    cv::cvtColor(matSmall, matHSV, CV_BGR2HSV);
    
    // NOTE: argument 2 & 3 represent the bounds of H, S, V
    cv::inRange(matHSV, cv::Scalar(_hMin, _sMin, _vMin), cv::Scalar(_hMax, _sMax, _vMax), matThresh);
    
    // IMPORTANT: Keep this before findContours
    // We'll always return the preview because this doesn't need to be real-time
    UIImage *imgOutput = [UIImage imageWithCVMat:matThresh];
    
    // Now, do some contour detection
    vector<vector<cv::Point> > contoursOrange;
    cv::findContours(matThresh, contoursOrange, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
    
    CGRect rectBlob = GetLargestContour(&contoursOrange);
    
    blockComplete(rectBlob, imgOutput);

}

- (void)displayBlob:(CGRect)rectBlob
            inImage:(UIImage *)threshImage
       forVideoRect:(CGRect)rect
   videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	   
    // Create transform to convert from vide frame coordinate space to view coordinate space
    //CGAffineTransform t = [self affineTransformForVideoFrame:rect orientation:videoOrientation];
    
    CGSize sizeImage = threshImage.size;
    CGSize sizeFrame = [UIScreen mainScreen].bounds.size;

    float widthRatio = sizeFrame.width / sizeImage.width;
    float heightRatio = sizeFrame.height / sizeImage.height;
    // NOTE:
    // MAX == aspect fill
    // MIN == aspect fit
    float scaleRatio = MAX(widthRatio, heightRatio);
    CGAffineTransform t = CGAffineTransformMakeScale(scaleRatio, scaleRatio);
    rectBlob = CGRectApplyAffineTransform(rectBlob, t);
    
    CGSize sizeDelta = CGSizeMake((sizeImage.width * scaleRatio) - sizeFrame.width,
                                  (sizeImage.height * scaleRatio) - sizeFrame.height);

    // Account for the centering of the blob
    rectBlob.origin.x += sizeDelta.width * -0.5;
    rectBlob.origin.y += sizeDelta.height * -0.5;
    
    // w/ YES, x & y are transposed
    CGRect cropRect = [self cropRectForBlobRect:rectBlob
                                  inFrameOfSize:sizeFrame
                                 adjustForVideo:NO];

    CALayer *camLayer = nil;
    CALayer *featureLayer = nil;
    CALayer *captureLayer = nil;
    
    for(CALayer *l in self.view.layer.sublayers){
        if([l.name isEqualToString:@"BlobRect"]){
            if(featureLayer){
                [l removeFromSuperlayer];
            }else{
                featureLayer = l;
            }
        }else if([l.name isEqualToString:@"Threshold"]){
            if(camLayer){
                [l removeFromSuperlayer];
            }else{
                camLayer = l;
            }
        }else if([l.name isEqualToString:@"CaptureRect"]){
            if(captureLayer){
                [l removeFromSuperlayer];
            }else{
                captureLayer = l;
            }
        }
    }

    if(!camLayer){
        camLayer = [[CALayer alloc] init];
        camLayer.name = @"Threshold";
        camLayer.frame = [UIScreen mainScreen].bounds;
        // TODO: Keep this in sync w/ the capture layer
        camLayer.contentsGravity = kCAGravityResizeAspectFill;
        [self.view.layer insertSublayer:camLayer below:self.viewHUD.layer];
        //[self.view.layer addSublayer:camLayer];
    }
    
    if(!captureLayer){
        captureLayer = [[CALayer alloc] init];
        captureLayer.name = @"CaptureRect";
        captureLayer.borderColor = [[UIColor greenColor] CGColor];
        captureLayer.borderWidth = 1.0f;
        [self.view.layer insertSublayer:captureLayer
                                  above:camLayer];
    }
    
    if(!featureLayer){
        featureLayer = [[CALayer alloc] init];
        featureLayer.name = @"BlobRect";
        featureLayer.borderColor = [[UIColor redColor] CGColor];
        featureLayer.borderWidth = 1.0f;
        //        [self.view.layer addSublayer:featureLayer];
        [self.view.layer insertSublayer:featureLayer above:camLayer];
    }
    

    camLayer.contents = _showsThreshold ? (id)threshImage.CGImage : nil;
    featureLayer.frame = rectBlob;
    captureLayer.frame = cropRect;

    [CATransaction commit];
}

#pragma mark - Touch

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    for(UITouch *t in touches){
        if(t.tapCount > 0 && _currentViewState == ViewStatePreview){
            _showsThreshold = !_showsThreshold;
        }
    }
}

#pragma mark - Video Processing

- (void)processCapturedFrames
{    
    self.isProcessing = YES;
    _cropFramePrev = CGRectZero;
    
    self.labelLoading.text = NSLocalizedString(@"Processing Frames", @"Processing Frames label");
    [self.view addSubview:self.viewProcessing];
    
    float delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

        [self pauseCapture];
        
        self.recordedFrames = [NSMutableArray arrayWithCapacity:self.capturedFrames.count];
        for(UIImage *capImage in self.capturedFrames){
            [self processRecordedFrame:capImage];
        }
        
        self.capturedFrames = nil;
        
        self.isProcessing = NO;
        
        [self.viewProcessing removeFromSuperview];
        
        if(_startRecordingWhenMarkerAppears){
            
            // Just automatically start again
            [self resumeCapture];
            [self setViewState:ViewStatePreview];
            
        }else{
        
            [self startPlaying];
            
        }

    });

}

- (void)processRecordedFrame:(UIImage *)imgFrame
{    
    CGSize sizeFrame = imgFrame.size;
    
    cv::Mat mat = [imgFrame CVMat];
    cv::Mat matMunge(mat);
    
    cv::cvtColor(mat, mat, CV_BGR2RGB);
    imgFrame = [UIImage imageWithCVMat:mat];

    [self processFrame:matMunge
             videoRect:CGRectMake(0, 0, sizeFrame.width, sizeFrame.height)
            completion:^(CGRect rectBlob, UIImage *imgBlob) {
                
                if(rectBlob.size.width == 0 || rectBlob.size.height == 0){
                    
                    // Skip the frame if there is no blob
                    
                }else{
                    
                    // Crop the image around the marker

                    CGRect cropRect = [self cropRectForBlobRect:rectBlob
                                                  inFrameOfSize:sizeFrame
                                                 adjustForVideo:YES];
                    
                    CGImageRef imageRef = CGImageCreateWithImageInRect(imgFrame.CGImage, cropRect);
                    
                    UIImageOrientation imgOrientation = UIImageOrientationRight;
                    if(self.camera == CamFront){
                        imgOrientation = UIImageOrientationLeftMirrored;
                    }
                    UIImage *imgCrop = [UIImage imageWithCGImage:imageRef
                                                           scale:1.0
                                                     orientation:imgOrientation];
                    
                    imgCrop = [UIImage imageWithImage:imgCrop scaledToSize:CGSizeMake(MaxFrameDimension, MaxFrameDimension)];
                    
                    [self.recordedFrames addObject:imgCrop];
                    
                    CGImageRelease(imageRef);
                    
                }
                
            }];
}

- (CGRect)cropRectForBlobRect:(CGRect)rectBlob
                inFrameOfSize:(CGSize)sizeFrame
               adjustForVideo:(BOOL)shouldAdjust
{
    
    CGPoint rectCenter = CGPointMake(rectBlob.origin.x + (rectBlob.size.width * 0.5),
                                     rectBlob.origin.y + (rectBlob.size.height * 0.5));
    
    if(!shouldAdjust){
        // This is the preview
        // Flip x & y
        float tmp = rectCenter.x;
        rectCenter.x = rectCenter.y;
        rectCenter.y = tmp;
    }
    
    CGSize cropSize = CGSizeMake(rectBlob.size.width * _markerMargin,
                                 rectBlob.size.height * _markerMargin);
    
    float maxDimension = MAX(round(cropSize.width), round(cropSize.height));
    
    float x = rectCenter.x - (cropSize.width * 0.5);
    float y = rectCenter.y - (cropSize.height * 0.5);
    
    float maxWidth = floor(sizeFrame.width - x);
    float maxHeight = floor(sizeFrame.height - y);
    
    float maxMaxDimension = MAX(MIN(maxWidth, maxDimension), MIN(maxHeight, maxDimension));
    
    cropSize = CGSizeMake(maxMaxDimension, maxMaxDimension);
    
    x = rectCenter.x - (cropSize.width * 0.5);
    y = rectCenter.y - (cropSize.height * 0.5);
    
    CGRect cropRect = CGRectMake(MAX(0, round(x)),
                                 MAX(0, round(y)),
                                 cropSize.width,
                                 cropSize.height);
    
    // This just translates it 90 down
    cropRect = CGRectMake(cropRect.origin.y, cropRect.origin.x,
                          cropRect.size.height, cropRect.size.width);

    if(shouldAdjust && self.camera == CamBack){
        // This could probably be handled above
        cropRect.origin.y = sizeFrame.height - (cropRect.origin.y + cropRect.size.height);
    }
    
    return cropRect;
    
}

#pragma mark - Action Sheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex != actionSheet.cancelButtonIndex){
        NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
        if([buttonTitle isEqualToString:ActionSheetButtonTitleEmail]){
            [self shareGIFViaEmail];
        }else if([buttonTitle isEqualToString:ActionSheetButtonTitlePhotoLibrary]){
            [self saveGIFToPhotoLibrary];
        }else if([buttonTitle isEqualToString:ActionSheetButtonTitleSave]){
            [self saveGIFWithCompletion:^(NSURL *gifURL) {
                //...
            }];
        }
    }
}

#pragma mark - Exporting GIFs

- (void)saveGIFWithCompletion:(void (^)(NSURL *gifURL))completionBlock
{
    
    BOOL canSave = !!_imgViewAnimation && _imgViewAnimation.animationImages.count > 0;
    
    if(!canSave){
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Export Error", @"export error alert title")
                                    message:@"Could not export GIF"
                                   delegate:nil
                          cancelButtonTitle:@"Dismiss"
                          otherButtonTitles:nil] show];
        completionBlock(nil);
    }
     
    self.labelLoading.text = NSLocalizedString(@"Generating Animation", @"Generating animation label");
    
    [self.view addSubview:self.viewProcessing];
    float delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        NSString *gifPath = [self tmpGIFPath];
        BOOL didExport = [_imgViewAnimation exportToPath:gifPath];
        
        [self.viewProcessing removeFromSuperview];
        
        if(!didExport){
            
            [[[UIAlertView alloc] initWithTitle:nil
                                        message:@"Could not export GIF"
                                       delegate:nil
                              cancelButtonTitle:@"Dismiss"
                              otherButtonTitles:nil] show];
            
            completionBlock(nil);
            
        }else{
            
            completionBlock([NSURL fileURLWithPath:gifPath]);
            
        }
        
    });

}

- (void)saveGIFToPhotoLibrary
{
    [self saveGIFWithCompletion:^(NSURL *gifURL) {
        if(gifURL){
            
            self.labelLoading.text = NSLocalizedString(@"Saving Animation", @"Saving animation label");
            [self.view addSubview:self.viewProcessing];
            
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            NSData *imageData = [NSData dataWithContentsOfURL:gifURL];
            [library writeImageDataToSavedPhotosAlbum:imageData
                                             metadata:0
                                      completionBlock:^(NSURL *assetURL, NSError *error) {
                                          
                                          [self.viewProcessing removeFromSuperview];
                                          
                                          if(error){
                                              [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Export Error", @"export error alert title")
                                                                                              message:[error localizedDescription]
                                                                                             delegate:nil
                                                                                    cancelButtonTitle:NSLocalizedString(@"Dismiss", @"alert cancel button title")
                                                                otherButtonTitles:nil] show];
                                          }
                                          
                                      }];
            
        }
    }];
    
}

- (void)shareGIFViaEmail
{
    if([MFMailComposeViewController canSendMail]){
        
        [self saveGIFWithCompletion:^(NSURL *gifURL) {
            if(gifURL){
                
                MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
                
                mailer.mailComposeDelegate = self;
                [mailer setSubject:@"UTZ Cam GIF"];
                
                NSData *imageData = [NSData dataWithContentsOfURL:gifURL];
                [mailer addAttachmentData:imageData
                                 mimeType:@"image/gif"
                                 fileName:@"utzcam.gif"];
                
                NSString *emailBody = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"email_export" ofType:@"html"]
                                                                encoding:NSUTF8StringEncoding
                                                                   error:nil];
                /*
                NSString *dateString = [NSString stringWithFormat:@"%@", [NSDate date]];
                emailBody = [emailBody stringByReplacingOccurrencesOfString:@"__DATETIME__"
                                                                 withString:dateString];
                */
                [mailer setMessageBody:emailBody
                                isHTML:YES];
                
                mailer.modalPresentationStyle = UIModalPresentationFormSheet;
                
                [self presentViewController:mailer
                                   animated:YES
                                 completion:nil];
            }
        }];
        
    }else{
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Email Disabled", @"email disabled alert title")
                                                        message:NSLocalizedString(@"You must have an e-mail account configured to send this GIF. Accounts can be configured in the Settings app.", @"email disabled alert message")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Dismiss", @"alert cancel button title")
                                              otherButtonTitles:nil];
        [alert show];
    }

}

#pragma mark - Message Delegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

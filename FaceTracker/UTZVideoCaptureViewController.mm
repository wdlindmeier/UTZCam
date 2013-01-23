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
#import "UIImage+INResizeImageAllocator.h"
#import "CGGeometry.h"
#import "WDLAnimatedGIFView.h"
#import "CGCVHelpers.h"

using namespace std;

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
    BOOL _hasChangedColor;
    float _fpsCaptured;
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
        self.camera = 0;
        _showsThreshold = NO;
        _isPlaying = NO;
        self.isProcessing = NO;
        _isRecording = NO;
        _hasChangedColor = NO;
        self.torchOn = NO;

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

- (void)setTorchOn:(BOOL)isTorchOn
{
    [super setTorchOn:isTorchOn];
    
    if(!_hasChangedColor){
        
        if(!isTorchOn){
            
            // This is calibrated for a Cheeto w/ out the torch
            _hMin = 0;
            _hMax = 22;
            _sMin = 184;
            _sMax = 255;
            _vMin = 163;
            _vMax = 255;
            
        }else{
            
            // This is calibrated for a Cheeto w/ the torch
            _hMin = 0;
            _hMax = 22;
            _sMin = 194;
            _sMax = 255;
            _vMin = 118;
            _vMax = 255;
            
        }
    }
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
    [self sliderMoved:nil];

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

#pragma mark - IBAction

- (IBAction)buttonTorchPressed:(id)sender
{
    self.torchOn = !self.torchOn;
}

- (IBAction)sliderMoved:(id)sender
{
    _hasChangedColor = YES;
    
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
}

- (IBAction)buttonHUDPressed:(id)sender
{
    self.viewHUD.hidden = !self.viewHUD.hidden;
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

- (IBAction)buttonGIFPressed:(id)sender
{
    if(_imgViewAnimation){
        NSLog(@"Exporting gif...");
        BOOL didExport = [_imgViewAnimation exportToPath:[self tmpGIFPath]];
        if(!didExport){
            [[[UIAlertView alloc] initWithTitle:nil
                                        message:@"Could not export GIF"
                                       delegate:nil
                              cancelButtonTitle:@"Dismiss"
                              otherButtonTitles:nil] show];
            return;
        }
        NSLog(@"Success");
    }else{
        NSLog(@"Loading gif...");
        _imgViewAnimation = [[WDLAnimatedGIFView alloc] initWithGIFPath:[self tmpGIFPath]];
        if(!_imgViewAnimation){
            [[[UIAlertView alloc] initWithTitle:nil
                                        message:@"Could not load GIF"
                                       delegate:nil
                              cancelButtonTitle:@"Dismiss"
                              otherButtonTitles:nil] show];
            return;
        }
        NSLog(@"_imgViewAnimation: %@ num frames %i", _imgViewAnimation, _imgViewAnimation.animationImages.count);
        [self startImageViewPlayback];
    }
}

- (IBAction)buttonCamFlipPressed:(id)sender
{
    self.camera = (self.camera == 1) ? 0 : 1;
}

#pragma mark - View States

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
        
        _isRecording = YES;
        
        if(_isPlaying){
            [self stopPlaying];
        }
        
        self.recordedFrames = nil;
        self.capturedFrames = [NSMutableArray arrayWithCapacity:200];
        
        // JIK
        [self performSelector:@selector(stopRecording) withObject:nil afterDelay:3.0f];
    }    
}

- (void)stopRecording
{
    if(_isRecording){
        
        _fpsCaptured = _fps;
        _isRecording = NO;
        [self processCapturedFrames];

    }
}

- (void)stopPlaying
{
    [_imgViewAnimation removeFromSuperview];
    _imgViewAnimation = nil;
    
    [self resumeCapture];
    
    _isPlaying = NO;
}

- (void)startPlaying
{
     if(self.recordedFrames && self.recordedFrames.count > 0){
         
        NSLog(@"Playback");
         
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
        _imgViewAnimation.animationRepeatCount = 10e100;

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
                // This is a preview. Just show the blobs in a rect.
                [self displayBlob:rectBlob
                          inImage:imgBlob
                     forVideoRect:rect
                 videoOrientation:AVCaptureVideoOrientationPortrait];
                
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

    CALayer *camLayer = nil;
    CALayer *featureLayer = nil;
    
    for(CALayer *l in self.view.layer.sublayers){
        if([l.name isEqualToString:@"Blob"]){
            if(featureLayer){
                [l removeFromSuperlayer];
            }else{
                featureLayer = l;
            }
        }else if([l.name isEqualToString:@"Cam"]){
            if(camLayer){
                [l removeFromSuperlayer];
            }else{
                camLayer = l;
            }
        }
    }

    if(!camLayer){
        camLayer = [[CALayer alloc] init];
        camLayer.name = @"Cam";
        camLayer.frame = [UIScreen mainScreen].bounds;
        // TODO: Keep this in sync w/ the capture layer
        camLayer.contentsGravity = kCAGravityResizeAspectFill;
        [self.view.layer insertSublayer:camLayer below:self.viewHUD.layer];
        //[self.view.layer addSublayer:camLayer];
    }
    
    if(!featureLayer){
        featureLayer = [[CALayer alloc] init];
        featureLayer.name = @"Blob";
        featureLayer.borderColor = [[UIColor redColor] CGColor];
        featureLayer.borderWidth = 1.0f;
        //        [self.view.layer addSublayer:featureLayer];
        [self.view.layer insertSublayer:featureLayer above:camLayer];
    }
    

    camLayer.contents = _showsThreshold ? (id)threshImage.CGImage : nil;
    featureLayer.frame = rectBlob;

    [CATransaction commit];
}

#pragma mark - Touch

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    for(UITouch *t in touches){
        if(t.tapCount > 0){
            _showsThreshold = !_showsThreshold;
        }
    }
}

#pragma mark - Video Processing

- (void)processCapturedFrames
{    
    self.isProcessing = YES;
    _cropFramePrev = CGRectZero;
 
    NSLog(@"Processing frames");
    
    [self pauseCapture];
     
    // TODO: Show an activity indicator

    self.recordedFrames = [NSMutableArray arrayWithCapacity:self.capturedFrames.count];
    for(UIImage *capImage in self.capturedFrames){
        [self processRecordedFrame:capImage];
    }
    
    self.capturedFrames = nil;
    
    self.isProcessing = NO;
    
    [self startPlaying];
    
//    [self resumeCapture];

}

- (void)processRecordedFrame:(UIImage *)imgFrame
{    
    CGSize sizeFrame = imgFrame.size;
    
    cv::Mat mat = [imgFrame CVMat];
    cv::Mat matMunge(mat);
    
    // Flip, convert, transpose
    // aye aye aye!
    if (self.camera == 0){
        cv::flip(mat, mat, 0); // -1 == both, 0 == x, 1 == y
    }

    cv::cvtColor(mat, mat, CV_BGR2RGB);
    imgFrame = [UIImage imageWithCVMat:mat];
    imgFrame = [UIImage imageWithCGImage:imgFrame.CGImage
                                   scale:1.0
                             orientation:UIImageOrientationLeftMirrored];

    [self processFrame:matMunge
             videoRect:CGRectMake(0, 0, sizeFrame.width, sizeFrame.height)
            completion:^(CGRect rectBlob, UIImage *imgBlob) {
                
                if(rectBlob.size.width == 0 || rectBlob.size.height == 0){
                    
                    // Skip the frame if there is no blob
                    
                }else{
                    // Crop the image around the marker
                    
                    CGPoint rectCenter = CGPointMake(rectBlob.origin.x + (rectBlob.size.width * 0.5),
                                                     rectBlob.origin.y + (rectBlob.size.height * 0.5));
                    
                    // TEST
                    float tmp = rectCenter.y;
                    rectCenter.x = sizeFrame.width - rectCenter.x - rectBlob.size.width;
                    rectCenter.y = tmp;
                    
                    // TODO: Make this a settin
                    static const float FrameToMarkerMulti = 1.5f; //5.0f;
                    CGSize cropSize = CGSizeMake(rectBlob.size.width * FrameToMarkerMulti,
                                                 rectBlob.size.height * FrameToMarkerMulti);
                    
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
                    
                    /* // Skip avging
                    if(!CGRectEqualToRect(_cropFramePrev, CGRectZero)){
                        static const int NumFrameAvgs = 2;
                        // Average the frames
                        cropRect = CGRectMake((_cropFramePrev.origin.x + (cropRect.origin.x * NumFrameAvgs)) / (NumFrameAvgs+1),
                                              (_cropFramePrev.origin.y + (cropRect.origin.y * NumFrameAvgs)) / (NumFrameAvgs+1),
                                              (_cropFramePrev.size.width + (cropRect.size.width * NumFrameAvgs)) / (NumFrameAvgs+1),
                                              (_cropFramePrev.size.height + (cropRect.size.height * NumFrameAvgs)) / (NumFrameAvgs+1));
                    }
                    _cropFramePrev = cropRect;
                    */
                    
                    CGImageRef imageRef = CGImageCreateWithImageInRect(imgFrame.CGImage, cropRect);
                    UIImage *imgCrop = [UIImage imageWithCGImage:imageRef
                                                           scale:1.0
                                                     orientation:UIImageOrientationLeftMirrored];
                    
                    imgCrop = [UIImage imageWithImage:imgCrop scaledToSize:CGSizeMake(MaxFrameDimension, MaxFrameDimension)];
                    
                    [self.recordedFrames addObject:imgCrop];
                    
                    CGImageRelease(imageRef);
                    
                }
                
            }];
}

@end

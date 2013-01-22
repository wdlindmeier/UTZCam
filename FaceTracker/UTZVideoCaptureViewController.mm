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

using namespace std;

static inline UIImage* imageFromSampleBuffer(CMSampleBufferRef nextBuffer) {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(nextBuffer);
    // Lock the base address of the pixel buffer.
    //CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    // Get the number of bytes per row for the pixel buffer.
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height.
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space.
    static CGColorSpaceRef colorSpace = NULL;
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        if (colorSpace == NULL) {
            // Handle the error appropriately.
            return nil;
        }
    }
    
    // Get the base address of the pixel buffer.
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    
    // Create a Quartz direct-access data provider that uses data we supply.
    CGDataProviderRef dataProvider =
    CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    // Create a bitmap image from data supplied by the data provider.
    CGImageRef cgImage =
    CGImageCreate(width, height, 8, 32, bytesPerRow,
                  colorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                  dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    
    // Create and return an image object to represent the Quartz image.
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    return image;
}

static inline UIInterfaceOrientation OrientationForAssetTrack(AVAssetTrack *assetTrack)
{
    CGSize size = [assetTrack naturalSize];
    CGAffineTransform txf = [assetTrack preferredTransform];
    
    if (size.width == txf.tx && size.height == txf.ty)
        return UIInterfaceOrientationLandscapeRight;
    else if (txf.tx == 0 && txf.ty == 0)
        return UIInterfaceOrientationLandscapeLeft;
    else if (txf.tx == 0 && txf.ty == size.width)
        return UIInterfaceOrientationPortraitUpsideDown;
    else
        return UIInterfaceOrientationPortrait;
}

static inline CGRect GetLargestContour(vector< vector<cv::Point> > *contours)
{
    CGRect largestContour = CGRectZero;
    float largestContourDimension = 0.0f;
    
    for (vector<vector<cv::Point> >::iterator it=contours->begin() ; it < contours->end(); it++ ){
        
        vector<cv::Point> pts = *it;
        cv::Mat pointsMatrix = cv::Mat(pts);
        
        cv::Rect bounds = cv::boundingRect(pointsMatrix);
        float largestDimension = MAX(bounds.width, bounds.height);
        
        if(largestDimension > largestContourDimension){
            largestContourDimension = largestDimension;
            largestContour = CGRectMake(bounds.x, bounds.y, bounds.width, bounds.height);
        }
    }

    return largestContour;
}

@interface UTZVideoCaptureViewController ()
{
    BOOL _showsThreshold;
    int _hMin, _hMax, _sMin, _sMax, _vMin, _vMax;
    BOOL _isPlaying;
    WDLAnimatedGIFView *_imgViewAnimation;
    UIImagePickerController *_videoPicker;
    UIInterfaceOrientation _videoOrientation;
    CGRect _cropFramePrev;
    BOOL _didFinishRendering;
}

@property (atomic, strong) NSMutableArray *recordedFrames;
@property (atomic, strong) AVAssetReader *assetReader;
@property (atomic, strong) AVAssetReaderTrackOutput * output;

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
        
        // This is calibrated for a Cheeto w/ out the torch
        _hMin = 0;
        _hMax = 22;
        _sMin = 184;
        _sMax = 255;
        _vMin = 163;
        _vMax = 255;
        
        // This is calibrated for a Cheeto w/ the torch
        _hMin = 0;
        _hMax = 22;
        _sMin = 194;
        _sMax = 255;
        _vMin = 118;
        _vMax = 255;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cameraIsReady:)
                                                     name:AVCaptureSessionDidStartRunningNotification
                                                   object:nil];

    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)cameraIsReady:(NSNotification *)note
{
    if(_videoPicker){
        dispatch_async(dispatch_get_main_queue(), ^{
            // TODO:
            // Show a countdown
            NSLog(@"Starting video capture");
            [_videoPicker startVideoCapture];
            
            float delayInSeconds = 3.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                // Only film 3 sec films max
                [self buttonDoneVideoPressed:nil];
            });
        });
    }
}

#pragma mark - Accessors

- (NSString *)tmpGIFPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:@"tmp.gif"];
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


- (IBAction)buttonCancelVideoPressed:(id)sender
{
    [self cancelVideoPicker];
}

- (IBAction)buttonDoneVideoPressed:(id)sender
{
    [_videoPicker stopVideoCapture];
    // Let the delegate handle canceling
}

- (IBAction)buttonRecordPressed:(id)sender
{
    [self cancelVideoPicker];
    
    self.recordedFrames = [NSMutableArray arrayWithCapacity:200];
    
    _videoPicker = [[UIImagePickerController alloc] init];
    _videoPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    _videoPicker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    _videoPicker.mediaTypes = [NSArray arrayWithObject:(id)kUTTypeMovie];
    _videoPicker.delegate = self;
    _videoPicker.videoQuality = UIImagePickerControllerQualityTypeHigh;
    _videoPicker.showsCameraControls = NO;
    _videoPicker.cameraOverlayView = self.viewCameraOverlay;
    _videoPicker.view.frame = self.view.bounds;
    [self presentViewController:_videoPicker animated:NO
                     completion:^{
                         //...
                     }];    
    
    [self pauseCapture];
}

- (IBAction)buttonPlayPressed:(id)sender
{

    if(_isPlaying){
        
        // stop
        
        [_imgViewAnimation removeFromSuperview];
        _imgViewAnimation = nil;
        
        [self resumeCapture];
        
        _isPlaying = NO;

    }else{
        
       // Play
        
        if(self.recordedFrames && self.recordedFrames.count > 0){
            
            [self pauseCapture];
            
            if(_imgViewAnimation){
                [_imgViewAnimation removeFromSuperview];
                _imgViewAnimation = nil;
            }
            
            _imgViewAnimation = [[WDLAnimatedGIFView alloc] initWithFrame:self.view.bounds];
            NSArray *imgs = [NSArray arrayWithArray:self.recordedFrames];
            _imgViewAnimation.animationImages = imgs;
            _imgViewAnimation.image = imgs[0];
            _imgViewAnimation.animationDuration = round(imgs.count / 30.0f);
            _imgViewAnimation.animationRepeatCount = 10e100;

            [self startImageViewPlayback];

        }else{
            
            NSLog(@"ERROR: Couldn't find recorded frames");
            
        }
        
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

#pragma mark - UIImagePicker

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.activityIndicator.hidden = NO;
    NSURL *videoURL = [info valueForKey:UIImagePickerControllerMediaURL];

    // TODO: Is this necessary?
    // Give it a slight delay to show the spinner
    float delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        NSLog(@"Scanning video");
        [self scanVideoAtURL:videoURL];
    });

}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self cancelVideoPicker];
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

- (void)cancelVideoPicker
{
    [self dismissModalViewControllerAnimated:NO];
    self.activityIndicator.hidden = YES;
    _videoPicker = nil;
    [self resumeCapture];
}

#pragma mark - Capture control

- (void)pauseCapture
{
    [_captureSession stopRunning];
}

- (void)resumeCapture
{
    [_captureSession startRunning];
}

#pragma mark - VideoCaptureViewController overrides

typedef void (^image_proc_block_t)(CGRect rectBlob, UIImage *imgBlob);

- (void)processFrame:(cv::Mat &)mat videoRect:(CGRect)rect videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
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

- (void)processFrame:(cv::Mat &)mat
           videoRect:(CGRect)rect
          completion:(image_proc_block_t)blockComplete
{

    if(CGRectEqualToRect(rect, CGRectZero)){
        blockComplete(CGRectZero, nil);
    }
    
    cv::Mat matSmall(mat);
    
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

- (void)readNextFrame
{
    if(self.assetReader.status == AVAssetReaderStatusReading){
        
        CMSampleBufferRef sampleBuffer = [self.output copyNextSampleBuffer];
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Lock the image buffer
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        // Get information of the image
        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
//        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t vWidth = CVPixelBufferGetWidth(imageBuffer);
        size_t vHeight = CVPixelBufferGetHeight(imageBuffer);
        
        if(vHeight > 0 && vWidth > 0){
        
            cv::Mat mat(vHeight, vWidth, CV_8UC4, baseAddress, 0);
            
            [self processFrame:mat
                     videoRect:CGRectMake(0, 0, vWidth, vHeight)
                    completion:^(CGRect rectBlob, UIImage *imgBlob) {

                        if(rectBlob.size.width == 0 || rectBlob.size.height == 0){
                            
                            // Skip the frame if there is no blob
                            
                        }else{
                            // Crop the image around the marker
                            
                            CGPoint rectCenter = CGPointMake(rectBlob.origin.x + (rectBlob.size.width * 0.5),
                                                             rectBlob.origin.y + (rectBlob.size.height * 0.5));
                            static const float FrameToMarkerMulti = 5.0f;
                            CGSize cropSize = CGSizeMake(rectBlob.size.width * FrameToMarkerMulti,
                                                         rectBlob.size.height * FrameToMarkerMulti);

                            float maxDimension = MAX(round(cropSize.width), round(cropSize.height));
                            
                            float x = rectCenter.x - (cropSize.width * 0.5);
                            float y = rectCenter.y - (cropSize.height * 0.5);

                            float maxWidth = floor(vWidth - x);
                            float maxHeight = floor(vHeight - y);
                            
                            float maxMaxDimension = MAX(MIN(maxWidth, maxDimension), MIN(maxHeight, maxDimension));

                            cropSize = CGSizeMake(maxMaxDimension, maxMaxDimension);
                            
                            x = rectCenter.x - (cropSize.width * 0.5);
                            y = rectCenter.y - (cropSize.height * 0.5);
                            
                            CGRect cropRect = CGRectMake(MAX(0, round(x)),
                                                         MAX(0, round(y)),
                                                         cropSize.width,
                                                         cropSize.height);

                            // Not the most efficient, but it works
                            UIImage *videoImage = imageFromSampleBuffer(sampleBuffer);
                            
                            // This just translates it 90 down
                            cropRect = CGRectMake(cropRect.origin.y, cropRect.origin.x,
                                                  cropRect.size.height, cropRect.size.width);
                            
                            if(!CGRectEqualToRect(_cropFramePrev, CGRectZero)){
                                static const int NumFrameAvgs = 2;
                                // Average the frames
                                cropRect = CGRectMake((_cropFramePrev.origin.x + (cropRect.origin.x * NumFrameAvgs)) / (NumFrameAvgs+1),
                                                      (_cropFramePrev.origin.y + (cropRect.origin.y * NumFrameAvgs)) / (NumFrameAvgs+1),
                                                      (_cropFramePrev.size.width + (cropRect.size.width * NumFrameAvgs)) / (NumFrameAvgs+1),
                                                      (_cropFramePrev.size.height + (cropRect.size.height * NumFrameAvgs)) / (NumFrameAvgs+1));
                            }
                            _cropFramePrev = cropRect;
                            
                            CGImageRef imageRef = CGImageCreateWithImageInRect(videoImage.CGImage, cropRect);
                            UIImage *imgCrop = [UIImage imageWithCGImage:imageRef scale:1.0 orientation:UIImageOrientationLeftMirrored];
                            
                            imgCrop = [UIImage imageWithImage:imgCrop scaledToSize:CGSizeMake(300, 300)];
                            
                            [self.recordedFrames addObject:imgCrop];

                            // Does this not get released?
                            CGImageRelease(imageRef);

                        }
                        

                        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
                        CMSampleBufferInvalidate(sampleBuffer);
                        CFRelease(sampleBuffer);
                        
                        [self readNextFrame];

                    }];
        }else{

            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            CMSampleBufferInvalidate(sampleBuffer);
            // THIS CAUSES CRASH
            // CFRelease(sampleBuffer);

            [self readNextFrame];
            
        }

    }else{
    
        NSLog(@"FINISHED reading");
        
        // NOTE: If we use multiple queues, add a BOOL flag here to avoid repeat cleanup
        
    }
}
         
- (void)scanVideoAtURL:(NSURL *)assetURL
{
    //ZBarImageScanner *zScanner = [[ZBarImageScanner alloc] init];
    AVAsset *videoAsset = [[AVURLAsset alloc] initWithURL:assetURL options:0];
    NSError *readError = nil;
    _didFinishRendering = NO;
    self.assetReader = [[AVAssetReader alloc] initWithAsset:videoAsset
                                                      error:&readError];
    if(readError){
        
        NSLog(@"ERROR: Could not read video asset: %@", readError);
        
    }else{
        
        _cropFramePrev = CGRectZero;
        
        NSArray *videoTracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *videoTrack = [videoTracks objectAtIndex:0];
        _videoOrientation = OrientationForAssetTrack(videoTrack);
        NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA], (NSString*)kCVPixelBufferPixelFormatTypeKey,
                                       nil];
        [self.assetReader addOutput:[AVAssetReaderTrackOutput
                                     assetReaderTrackOutputWithTrack:videoTrack
                                     outputSettings:videoSettings]];

        [self dismissViewControllerAnimated:NO
                                 completion:^{
                                     _videoPicker = nil;
                                     [self.assetReader startReading];
                                     self.output = [self.assetReader.outputs objectAtIndex:0];
                                     [self readNextFrame];
                                 }];

        /*
        int numQueues = 3;
        
        for(int i=0;i<numQueues;i++){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                [self readNextFrame];
            });
        }*/
    }
}


@end

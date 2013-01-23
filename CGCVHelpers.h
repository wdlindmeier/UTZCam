//
//  CGCVHelpers.h
//  UTZ Cam
//
//  Created by William Lindmeier on 1/22/13.
//
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

using namespace std;

static inline UIImage* UIImageFromImageBuffer(CVPixelBufferRef imageBuffer)//(CMSampleBufferRef nextBuffer)
{
    
    // CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(nextBuffer);
    
    // Lock the base address of the pixel buffer.
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
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
                  colorSpace, kCGImageAlphaNone | kCGBitmapByteOrderDefault,
                  // kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault,
                  //kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
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

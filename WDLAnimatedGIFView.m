//
//  WDLAnimatedGIFView.m
//  UTZ Cam
//
//  Created by William Lindmeier on 1/22/13.
//
//

#import "WDLAnimatedGIFView.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "AnimatedGif.h"

@implementation WDLAnimatedGIFView

- (id)initWithGIFPath:(NSString *)path
{
    self = [super initWithFrame:CGRectZero];
    if(self){
     
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if(!fileExists){
            NSLog(@"ERROR: Could not load GIF from path: %@", path);
            return nil;
        }
        
        NSURL *gifURL = [NSURL fileURLWithPath:path];
        UIImageView * gifView = [AnimatedGif getAnimationForGifAtUrl: gifURL];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(imageViewWasLoaded:)
                                                     name:AnimatedGifNotificationWasLoaded
                                                   object:gifView];
    }
    
    return self;

}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)imageViewWasLoaded:(NSNotification *)note
{
    UIImageView *loadedView = [note object];
    
    dispatch_async(dispatch_get_main_queue(), ^{

        // self.frame = loadedView.frame;
        self.animationImages = loadedView.animationImages;
        self.animationDuration = loadedView.animationDuration;
        self.animationRepeatCount = loadedView.animationRepeatCount;
        [self startAnimating];
        
        // Remove the loaded view from the animated gif loader
        // This seems to cause issues. The memory management isn't working in the AnimatedGif class.
        [AnimatedGif sharedInstance].imageView = nil;
        
    });

}

#pragma mark - Image Export

- (BOOL)exportToPath:(NSString *)path
{
    NSURL *gifURL = [NSURL fileURLWithPath:path];
    
    int numFrames = self.animationImages.count;
    float duration = self.animationDuration;
    float frameDelay = duration / numFrames;
    int loopCount = self.animationRepeatCount;
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL,
                                                                        kUTTypeGIF,
                                                                        numFrames,
                                                                        NULL);
    NSDictionary *frameProperties = @{ (NSString *)kCGImagePropertyGIFDictionary :
                                       @{ (NSString *)kCGImagePropertyGIFDelayTime : @(frameDelay)} };
    NSDictionary *gifProperties = @{ (NSString *)kCGImagePropertyGIFDictionary :
                                     @{ (NSString *)kCGImagePropertyGIFLoopCount : @(loopCount)} };
    for(UIImage *img in self.animationImages){
        CGImageDestinationAddImage(destination, img.CGImage, (__bridge CFDictionaryRef)frameProperties);
    }
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

/*

static UIImage *animatedImageWithAnimatedGIFImageSource(CGImageSourceRef source, NSTimeInterval duration) {
    if (!source)
        return nil;
    
    size_t count = CGImageSourceGetCount(source);
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; ++i) {
        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (!cgImage)
            return nil;
        [images addObject:[UIImage imageWithCGImage:cgImage]];
        CGImageRelease(cgImage);
    }
    
    return [UIImage animatedImageWithImages:images duration:duration];
}

static UIImage *animatedImageWithAnimatedGIFReleasingImageSource(CGImageSourceRef source, NSTimeInterval duration) {
    UIImage *image = animatedImageWithAnimatedGIFImageSource(source, duration);
    CFRelease(source);
    return image;
}
+ (UIImage *)animatedImageWithAnimatedGIFData:(NSData *)data duration:(NSTimeInterval)duration
{
    return animatedImageWithAnimatedGIFReleasingImageSource(CGImageSourceCreateWithData((__bridge CFTypeRef) data, NULL), duration);
}

+ (UIImage *)animatedImageWithAnimatedGIFURL:(NSURL *)url duration:(NSTimeInterval)duration
{
    return animatedImageWithAnimatedGIFReleasingImageSource(CGImageSourceCreateWithURL((__bridge CFTypeRef) url, NULL), duration);
}
*/
@end

//
//  NSObject+MiscHelpers.m
//  NetflixQual
//
//  Created by William Lindmeier on 9/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSObject+MiscHelpers.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSObject(MiscHelpers)
@end

@implementation NSString(MiscHelpers)

- (BOOL)isNotBlank
{
    return [[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

+ (NSDictionary *)dictionaryFromQueryParams:(NSString *)paramsString lowercaseKeys:(BOOL)shouldLowercase
{	
	// If the string starts with a ?, lop it off
	NSString *queryString = [paramsString stringByReplacingOccurrencesOfString:@"?" withString:@""];
	
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	
	NSArray *paramKeyValues = [queryString componentsSeparatedByString:@"&"];		
	
	for(NSString *param in paramKeyValues){
		NSArray *keyValue = [param componentsSeparatedByString:@"="];
		NSString *theKey = [keyValue objectAtIndex:0];
		if(shouldLowercase) theKey = [theKey lowercaseString];
		[options setObject:[keyValue objectAtIndex:1] forKey:theKey];
	}
	
	return options;	
}

+ (NSString *)createGUID
{
	CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef strRef = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
	NSString *uuidString = [NSString stringWithString:(__bridge NSString*)strRef];
	CFRelease(strRef);
	CFRelease(uuidRef);	
	return uuidString;
}

@end


@implementation NSArray(MiscHelpers)

- (NSArray *)reversedArray {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[self count]];
    NSEnumerator *enumerator = [self reverseObjectEnumerator];
    for (id element in enumerator) {
        [array addObject:element];
    }
    return array;
}

@end

@implementation UIView(MiscHelpers)

- (UIImage *)renderedAsImage
{
	CGSize imageSize = self.bounds.size;
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
		UIGraphicsBeginImageContextWithOptions(imageSize, NO, [[UIScreen mainScreen] scale]);
	} else {
		UIGraphicsBeginImageContext(imageSize);
	}
	// UIGraphicsBeginImageContext(self.bounds.size);
	[self.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return viewImage;
}

- (CGRect)frameWithinView:(UIView *)otherView
{
    CGPoint adjustedPosition = [self positionWithinView:otherView];
    return CGRectMake(adjustedPosition.x, adjustedPosition.y, self.frame.size.width, self.frame.size.height);
}

- (CGPoint)positionWithinView:(UIView *)otherView
{
	CGPoint position = CGPointMake(0.0, 0.0);
	if([self isDescendantOfView:otherView]){
		UIView *parent = self;		
		while(parent != otherView){
            CGPoint scrollOffset = CGPointZero;
            if([parent isKindOfClass:[UIScrollView class]]){
                scrollOffset = ((UIScrollView *)parent).contentOffset;
            }
			position = CGPointMake(position.x + parent.frame.origin.x - scrollOffset.x, 
                                   position.y + parent.frame.origin.y - scrollOffset.y);
			parent = parent.superview;
		}
	}else if([otherView isDescendantOfView:self.superview]){
        CGPoint posOtherView = [otherView positionWithinView:self.superview];
        CGPoint posMe = self.frame.origin;
        position = CGPointMake((posMe.x - posOtherView.x),
                               (posMe.y - posOtherView.y));
    }
	return position;
}

- (void)setFrameX:(float)newX
{
    self.frame = CGRectMake(newX, self.frame.origin.y, 
                            self.frame.size.width, 
                            self.frame.size.height);
}

- (void)setFrameY:(float)newY
{
    self.frame = CGRectMake(self.frame.origin.x, newY, 
                            self.frame.size.width, 
                            self.frame.size.height);
}

- (void)setFrameWidth:(float)newWidth
{
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, 
                            newWidth, 
                            self.frame.size.height);
}

- (void)setFrameHeight:(float)newHeight
{
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, 
                            self.frame.size.width, 
                            newHeight);
}

- (void)roundFrame
{
    CGRect myFrame = self.frame;
    self.frame = CGRectMake(round(myFrame.origin.x), round(myFrame.origin.y), 
                            round(myFrame.size.width), round(myFrame.size.height));
    
}

@end

/*
@implementation UINavigationBar(MiscHelpers)

- (void)drawRect:(CGRect)rect {
    UIImage *image = [UIImage imageNamed: @"navbar_bg_red.png"];
    [image drawInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
}

@end
*/

@implementation CALayer(MiscHelpers)

-(void)pause
{
    if(self.speed != 0.0){
        CFTimeInterval pausedTime = [self convertTime:CACurrentMediaTime() fromLayer:nil];
        self.speed = 0.0;
        self.timeOffset = pausedTime;
    }
}

-(void)resume
{
    if(self.speed != 1){
        CFTimeInterval pausedTime = [self timeOffset];
        self.speed = 1.0;
        self.timeOffset = 0.0;
        self.beginTime = 0.0;
        CFTimeInterval timeSincePause = [self convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
        self.beginTime = timeSincePause;
    }
}

- (void)changeSpeed:(float)newSpeed
{
    self.timeOffset = [self convertTime:CACurrentMediaTime() fromLayer:nil];
    self.beginTime = CACurrentMediaTime();
    self.speed = newSpeed;
}

@end
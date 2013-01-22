//
//  WDLAnimatedGIFView.h
//  UTZ Cam
//
//  Created by William Lindmeier on 1/22/13.
//
//

#import <UIKit/UIKit.h>

@interface WDLAnimatedGIFView : UIImageView

- (id)initWithGIFPath:(NSString *)path;
- (BOOL)exportToPath:(NSString *)path;

@end

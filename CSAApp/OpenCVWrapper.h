#import <Foundation/Foundation.h>

@class UIImage;

@interface OpenCVWrapper : NSObject
+ (NSDictionary *)processImageWithCircleDetectionAndCrop:(UIImage *)image;
@end

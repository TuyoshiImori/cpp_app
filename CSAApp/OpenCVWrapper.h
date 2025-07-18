#import <Foundation/Foundation.h>
@class UIImage;

@interface OpenCVWrapper : NSObject
+ (UIImage *)processImage:(UIImage *)image;
+ (NSArray<NSValue *> *)detectCircles:(UIImage *)image;
+ (NSArray<UIImage *> *)cropImagesByCircles:(UIImage *)image;
@end

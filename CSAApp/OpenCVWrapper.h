#import <Foundation/Foundation.h>

@class UIImage;

@interface OpenCVWrapper : NSObject
// 既存 API
+ (NSDictionary *)processImageWithCircleDetectionAndCrop:(UIImage *)image;
// 新 API: StoredType の文字列配列を渡して OpenCV 内で処理ごとの分岐・ログを出す
+ (NSDictionary *)processImageWithCircleDetectionAndCrop:(UIImage *)image withStoredTypes:(NSArray<NSString *> *)types;
@end

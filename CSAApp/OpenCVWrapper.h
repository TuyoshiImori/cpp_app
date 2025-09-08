#import <Foundation/Foundation.h>

@class UIImage;

@interface OpenCVWrapper : NSObject
// APIの命名は処理内容がわかりやすいようにする
+ (NSDictionary *)processImageWithCircleDetectionAndCrop:(UIImage *)image;

// Cropped images parsing API
// - image: 元画像（処理済み/参照用）
// - croppedImages: 切り取った設問画像の配列（UIImage）
// - types: 設問の StoredType を表す文字列配列（"single" | "multiple" | "text" | "info"）
// - optionCounts: 各設問の選択肢数を NSNumber 配列で渡す（single/multiple は正の数、その他は 0）
 + (NSDictionary *)parseCroppedImages:(UIImage *)image
								 withCroppedImages:(NSArray<UIImage *> *)croppedImages
									 withStoredTypes:(NSArray<NSString *> *)types
									 withOptionCounts:(NSArray<NSNumber *> *)optionCounts;
@end

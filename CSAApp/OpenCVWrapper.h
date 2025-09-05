#import <Foundation/Foundation.h>

@class UIImage;

@interface OpenCVWrapper : NSObject
// 既存 API: 画像からマーカー(円)を検出して設問ごとに切り取りを行う
+ (NSDictionary *)detectCirclesAndCrop:(UIImage *)image;
// 新 API: StoredType の文字列配列を渡して切り取り後に各タイプごとに解析を行う
+ (NSDictionary *)detectAndParseWithStoredTypes:(UIImage *)image withStoredTypes:(NSArray<NSString *> *)types;
// 新 API: 既に切り取った画像リストを渡し、StoredTypeごとの解析を行う（カメラ側で切り取りを取得して渡す用途）
+ (NSDictionary *)parseCroppedImages:(UIImage *)image withCroppedImages:(NSArray<UIImage *> *)croppedImages withStoredTypes:(NSArray<NSString *> *)types;
@end

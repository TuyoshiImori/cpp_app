
#import "OpenCVWrapper.h"
#import <UIKit/UIKit.h>

// Apple の NO マクロを一時的に無効化してからOpenCVをインクルード
#ifdef NO
#undef NO
#endif

#import <opencv2/imgcodecs.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/imgproc.hpp>
#import <opencv2/opencv.hpp>

using namespace cv;

@implementation OpenCVWrapper

+ (UIImage *)processImage:(UIImage *)image {
  // 入力画像のnilチェック
  if (image == nil) {
    NSLog(@"OpenCVWrapper: 入力画像がnilです");
    return nil;
  }

  // UIImage -> cv::Mat
  cv::Mat mat;
  UIImageToMat(image, mat);

  // 入力画像が空の場合はnilを返す
  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: 入力画像が空です");
    return nil;
  }

  NSLog(@"OpenCVWrapper: 元画像 channels=%d, type=%d, size=%dx%d",
        mat.channels(), mat.type(), mat.cols, mat.rows);

  // 1. リサイズ
  CGFloat targetWidth = 1024;
  CGFloat scale = targetWidth / MAX(image.size.width, image.size.height);
  cv::Size newSize(image.size.width * scale, image.size.height * scale);

  // newSizeの幅・高さが0以下の場合はnilを返す
  if (newSize.width <= 0 || newSize.height <= 0) {
    NSLog(@"OpenCVWrapper: newSizeが不正です width=%d height=%d", newSize.width,
          newSize.height);
    return nil;
  }

  cv::Mat resizedMat;
  try {
    cv::resize(mat, resizedMat, newSize);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: リサイズでエラー: %s", e.what());
    return nil;
  }

  if (resizedMat.empty()) {
    NSLog(@"OpenCVWrapper: リサイズ後の画像が空です");
    return nil;
  }

  // 2. グレースケール変換（チャンネル数に応じて適切な変換を選択）
  cv::Mat grayMat;
  try {
    if (resizedMat.channels() == 4) {
      // RGBA -> GRAY
      cv::cvtColor(resizedMat, grayMat, cv::COLOR_RGBA2GRAY);
    } else if (resizedMat.channels() == 3) {
      // BGR -> GRAY
      cv::cvtColor(resizedMat, grayMat, cv::COLOR_BGR2GRAY);
    } else if (resizedMat.channels() == 1) {
      // 既にグレースケール
      grayMat = resizedMat.clone();
    } else {
      NSLog(@"OpenCVWrapper: 未対応のチャンネル数: %d", resizedMat.channels());
      return nil;
    }
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: グレースケール変換でエラー: %s", e.what());
    return nil;
  }

  if (grayMat.empty()) {
    NSLog(@"OpenCVWrapper: グレースケール変換後の画像が空です");
    return nil;
  }

  // 3. 鮮鋭化（アンシャープマスク）
  cv::Mat blurMat;
  try {
    cv::GaussianBlur(grayMat, blurMat, cv::Size(0, 0), 3);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: GaussianBlurでエラー: %s", e.what());
    return nil;
  }

  if (blurMat.empty()) {
    NSLog(@"OpenCVWrapper: GaussianBlur後の画像が空です");
    return nil;
  }

  cv::Mat sharpMat;
  try {
    cv::addWeighted(grayMat, 1.5, blurMat, -0.5, 0, sharpMat);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: addWeightedでエラー: %s", e.what());
    return nil;
  }

  if (sharpMat.empty()) {
    NSLog(@"OpenCVWrapper: addWeighted後の画像が空です");
    return nil;
  }

  // 4. 二値化
  cv::Mat binMat;
  try {
    cv::threshold(sharpMat, binMat, 180, 255, cv::THRESH_BINARY);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: thresholdでエラー: %s", e.what());
    return nil;
  }

  if (binMat.empty()) {
    NSLog(@"OpenCVWrapper: 二値化後の画像が空です");
    return nil;
  }

  // 5. モルフォロジー（クロージング）
  cv::Mat morphMat;
  try {
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3));
    cv::morphologyEx(binMat, morphMat, cv::MORPH_CLOSE, kernel);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: morphologyExでエラー: %s", e.what());
    return nil;
  }

  if (morphMat.empty()) {
    NSLog(@"OpenCVWrapper: モルフォロジー後の画像が空です");
    return nil;
  }

  // cv::Mat -> UIImage
  UIImage *result = nil;
  try {
    result = MatToUIImage(morphMat);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: MatToUIImageでエラー: %s", e.what());
    return nil;
  }

  if (result == nil) {
    NSLog(@"OpenCVWrapper: 最終的なUIImageがnilです");
    return nil;
  }

  return result;
}

@end

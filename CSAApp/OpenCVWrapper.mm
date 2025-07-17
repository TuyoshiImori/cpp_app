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

  // 画像を拡大
  cv::Mat resizedMat;
  try {
    cv::resize(mat, resizedMat, cv::Size(), 2.0, 2.0, cv::INTER_LINEAR);
  } catch (const cv::Exception &e) {
    std::cerr << "OpenCVWrapper: resizeでエラー: " << e.what() << std::endl;
    return nil;
  }

  if (resizedMat.empty()) {
    std::cerr << "OpenCVWrapper: 拡大後の画像が空です" << std::endl;
    return nil;
  }

  // 1. グレースケール変換
  cv::Mat grayMat;
  try {
    if (resizedMat.channels() == 4) {
      cv::cvtColor(resizedMat, grayMat, cv::COLOR_RGBA2GRAY);
    } else if (resizedMat.channels() == 3) {
      cv::cvtColor(resizedMat, grayMat, cv::COLOR_BGR2GRAY);
    } else if (resizedMat.channels() == 1) {
      grayMat = resizedMat.clone();
    } else {
      std::cerr << "OpenCVWrapper: 未対応のチャンネル数: "
                << resizedMat.channels() << std::endl;
      return nil;
    }
  } catch (const cv::Exception &e) {
    std::cerr << "OpenCVWrapper: グレースケール変換でエラー: " << e.what()
              << std::endl;
    return nil;
  }

  if (grayMat.empty()) {
    NSLog(@"OpenCVWrapper: グレースケール変換後の画像が空です");
    return nil;
  }

  // 2. ガウシアンブラーで平滑化
  cv::Mat blurMat;
  try {
    cv::GaussianBlur(grayMat, blurMat, cv::Size(3, 3), 0);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: GaussianBlurでエラー: %s", e.what());
    return nil;
  }

  // 3. 適応的二値化
  cv::Mat binaryMat;
  try {
    cv::adaptiveThreshold(blurMat, binaryMat, 255,
                          cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY, 19,
                          2);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: adaptiveThresholdでエラー: %s", e.what());
    return nil;
  }

  // 4. 白黒反転
  cv::Mat invMat;
  try {
    cv::bitwise_not(binaryMat, invMat);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: bitwise_notでエラー: %s", e.what());
    return nil;
  }

  // 5. ノイズ除去（モルフォロジーオープン）
  cv::Mat noNoiseMat;
  try {
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(2, 2));
    cv::morphologyEx(invMat, noNoiseMat, cv::MORPH_OPEN, kernel);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: morphologyExでエラー: %s", e.what());
    return nil;
  }

  // 6. 再度反転
  cv::Mat finalMat;
  try {
    cv::bitwise_not(noNoiseMat, finalMat);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: bitwise_not(2)でエラー: %s", e.what());
    return nil;
  }

  // 最終画像をUIImageに変換
  UIImage *result = nil;
  try {
    result = MatToUIImage(finalMat);
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

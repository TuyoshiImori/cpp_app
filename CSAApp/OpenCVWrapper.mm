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

  // スケーリング係数を計算
  double scaleX = static_cast<double>(mat.cols) / resizedMat.cols;
  double scaleY = static_cast<double>(mat.rows) / resizedMat.rows;

  // 円検出
  std::vector<cv::Vec3f> circles;
  try {
    cv::HoughCircles(grayMat, circles, cv::HOUGH_GRADIENT, 1,
                     grayMat.rows / 8.0, 200, 100, 0, 0);

    // 検出した円の座標をスケーリングして元の画像サイズに合わせる
    for (auto &circle : circles) {
      circle[0] *= scaleX; // x座標
      circle[1] *= scaleY; // y座標
    }
  } catch (const cv::Exception &e) {
    std::cerr << "OpenCVWrapper: HoughCirclesでエラー: " << e.what()
              << std::endl;
    return nil;
  }

  // 円の座標を返すための処理を追加
  std::vector<cv::Point> circleCenters;
  for (const auto &circle : circles) {
    circleCenters.emplace_back(cv::Point(circle[0], circle[1]));
  }

  // 最終画像をUIImageに変換
  UIImage *result = nil;
  try {
    result = MatToUIImage(finalMat);
  } catch (const cv::Exception &e) {
    std::cerr << "OpenCVWrapper: MatToUIImageでエラー: " << e.what()
              << std::endl;
    return nil;
  }

  if (result == nil) {
    std::cerr << "OpenCVWrapper: 最終的なUIImageがnilです" << std::endl;
    return nil;
  }

  return result;
}

+ (NSArray<NSValue *> *)detectCircles:(UIImage *)image {
  // 入力画像のnilチェック
  if (image == nil) {
    NSLog(@"OpenCVWrapper: detectCircles - 入力画像がnilです");
    return @[];
  }

  // UIImage -> cv::Mat
  cv::Mat mat;
  UIImageToMat(image, mat);

  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: detectCircles - 入力画像が空です");
    return @[];
  }

  NSLog(@"OpenCVWrapper: detectCircles - 画像サイズ: %dx%d, チャンネル数: %d",
        mat.cols, mat.rows, mat.channels());

  // グレースケール変換（元の画像から）
  cv::Mat grayMat;
  try {
    if (mat.channels() == 4) {
      cv::cvtColor(mat, grayMat, cv::COLOR_RGBA2GRAY);
    } else if (mat.channels() == 3) {
      cv::cvtColor(mat, grayMat, cv::COLOR_BGR2GRAY);
    } else if (mat.channels() == 1) {
      grayMat = mat.clone();
    } else {
      NSLog(@"OpenCVWrapper: detectCircles - 未対応のチャンネル数: %d",
            mat.channels());
      return @[];
    }
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: detectCircles - グレースケール変換でエラー: %s",
          e.what());
    return @[];
  }

  // 軽いガウシアンブラーでノイズ除去
  cv::Mat blurredMat;
  cv::GaussianBlur(grayMat, blurredMat, cv::Size(3, 3), 1.0);

  // 円検出（パラメータを大幅に緩和）
  std::vector<cv::Vec3f> circles;
  try {
    cv::HoughCircles(blurredMat, circles, cv::HOUGH_GRADIENT,
                     1,   // dp: 解像度の逆比
                     30,  // minDist: 円の中心間の最小距離
                     100, // param1: Cannyエッジ検出の上限閾値
                     80,  // param2: 円検出の閾値（大きいほど厳密）
                     20,  // minRadius: 最小半径
                     80); // maxRadius: 最大半径

    NSLog(@"OpenCVWrapper: detectCircles - 検出された円の数: %zu",
          circles.size());

    // 検出した円の詳細をログ出力
    for (size_t i = 0; i < circles.size(); i++) {
      if (circles[i][2] >= 10 && circles[i][2] <= 100) { // 半径フィルタリング
        NSLog(@"円 %zu: 中心(%f, %f), 半径%f", i, circles[i][0], circles[i][1],
              circles[i][2]);
      }
    }
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: detectCircles - HoughCirclesでエラー: %s", e.what());
    return @[];
  }

  // 円の座標をNSArrayに変換
  NSMutableArray<NSValue *> *circleCenters = [NSMutableArray array];
  for (const auto &circle : circles) {
    CGPoint center = CGPointMake(circle[0], circle[1]);
    [circleCenters addObject:[NSValue valueWithCGPoint:center]];
  }

  NSLog(@"OpenCVWrapper: detectCircles - 返す円の数: %lu",
        (unsigned long)[circleCenters count]);
  return circleCenters;
}

+ (NSArray<UIImage *> *)cropImagesByCircles:(UIImage *)image {
  // 入力画像のnilチェック
  if (image == nil) {
    NSLog(@"OpenCVWrapper: cropImagesByCircles - 入力画像がnilです");
    return @[ image ];
  }

  // UIImage -> cv::Mat
  cv::Mat mat;
  UIImageToMat(image, mat);

  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: cropImagesByCircles - 入力画像が空です");
    return @[ image ];
  }

  NSLog(@"OpenCVWrapper: cropImagesByCircles - 画像サイズ: %dx%d, "
        @"チャンネル数: %d",
        mat.cols, mat.rows, mat.channels());

  // グレースケール変換
  cv::Mat grayMat;
  try {
    if (mat.channels() == 4) {
      cv::cvtColor(mat, grayMat, cv::COLOR_RGBA2GRAY);
    } else if (mat.channels() == 3) {
      cv::cvtColor(mat, grayMat, cv::COLOR_BGR2GRAY);
    } else if (mat.channels() == 1) {
      grayMat = mat.clone();
    } else {
      NSLog(@"OpenCVWrapper: cropImagesByCircles - 未対応のチャンネル数: %d",
            mat.channels());
      return @[ image ];
    }
  } catch (const cv::Exception &e) {
    NSLog(
        @"OpenCVWrapper: cropImagesByCircles - グレースケール変換でエラー: %s",
        e.what());
    return @[ image ];
  }

  // 軽いガウシアンブラーでノイズ除去
  cv::Mat blurredMat;
  cv::GaussianBlur(grayMat, blurredMat, cv::Size(3, 3), 1.0);

  // 円検出
  std::vector<cv::Vec3f> circles;
  try {
    cv::HoughCircles(blurredMat, circles, cv::HOUGH_GRADIENT,
                     1,    // dp: 解像度の逆比
                     30,   // minDist: 円の中心間の最小距離
                     100,  // param1: Cannyエッジ検出の上限閾値
                     50,   // param2: 円検出の閾値
                     10,   // minRadius: 最小半径
                     100); // maxRadius: 最大半径

    NSLog(@"OpenCVWrapper: cropImagesByCircles - 検出された円の数: %zu",
          circles.size());
    for (size_t i = 0; i < circles.size(); i++) {
      const auto &circle = circles[i];
      NSLog(@"OpenCVWrapper: cropImagesByCircles - 円%zu: 中心(%f, %f), 半径%f",
            i, circle[0], circle[1], circle[2]);
    }
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: cropImagesByCircles - HoughCirclesでエラー: %s",
          e.what());
    return @[ image ];
  }

  // 円が検出されなかった場合は元の画像をそのまま返す
  if (circles.empty()) {
    NSLog(@"OpenCVWrapper: cropImagesByCircles - 円が検出されませんでした");
    return @[ image ];
  }

  // 円をy座標でソート（上から下へ）
  std::sort(circles.begin(), circles.end(),
            [](const cv::Vec3f &a, const cv::Vec3f &b) { return a[1] < b[1]; });

  NSMutableArray<UIImage *> *croppedImages = [NSMutableArray array];

  NSLog(@"OpenCVWrapper: cropImagesByCircles - 切り取り領域計算開始");
  for (size_t i = 0; i < circles.size(); i++) {
    const auto &circle = circles[i];
    float centerX = circle[0];
    float centerY = circle[1];
    float radius = circle[2];

    // 円の左上の座標を始点とする
    int startX = static_cast<int>(centerX - radius);
    int startY = static_cast<int>(centerY - radius);

    // 画像の範囲内に調整
    startX = std::max(0, startX);
    startY = std::max(0, startY);

    // 横幅は画像の右端まで
    int width = mat.cols - startX;

    // 縦幅を計算：次の円までの距離、または画像の下端まで
    int height;
    if (i + 1 < circles.size()) {
      // 次の円がある場合：次の円の上端まで
      const auto &nextCircle = circles[i + 1];
      int nextCircleTop = static_cast<int>(nextCircle[1] - nextCircle[2]);
      height = nextCircleTop - startY;
    } else {
      // 最後の円の場合：画像の下端まで
      height = mat.rows - startY;
    }

    // 縦幅が0以下の場合はスキップ
    if (height <= 0) {
      NSLog(@"OpenCVWrapper: cropImagesByCircles - 円%zu: 高さが不正 (%d)", i,
            height);
      continue;
    }

    // 画像の範囲内に調整
    height = std::min(height, mat.rows - startY);

    NSLog(@"OpenCVWrapper: cropImagesByCircles - 円%zu: 切り取り領域 x=%d, "
          @"y=%d, w=%d, h=%d",
          i, startX, startY, width, height);

    try {
      // 切り取り領域を定義
      cv::Rect cropRect(startX, startY, width, height);

      // 元の画像から切り取り
      cv::Mat croppedMat = mat(cropRect);

      // UIImageに変換
      UIImage *croppedImage = MatToUIImage(croppedMat);
      if (croppedImage != nil) {
        [croppedImages addObject:croppedImage];
      }
    } catch (const cv::Exception &e) {
      NSLog(@"OpenCVWrapper: cropImagesByCircles - 円%zu: 切り取りでエラー: %s",
            i, e.what());
      continue;
    }
  }

  NSLog(@"OpenCVWrapper: cropImagesByCircles - 切り取った画像数: %lu",
        (unsigned long)[croppedImages count]);

  // 切り取った画像がない場合は元の画像を返す
  if ([croppedImages count] == 0) {
    return @[ image ];
  }

  return croppedImages;
}

@end

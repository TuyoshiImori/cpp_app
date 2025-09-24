#import "OpenCVWrapper.h"
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>

// Apple の NO マクロを一時的に無効化してからOpenCVをインクルード
#ifdef NO
#undef NO
#endif

#import <opencv2/imgcodecs.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/imgproc.hpp>
#import <opencv2/opencv.hpp>

// Swift のクラスが生成されていればブリッジヘッダをインクルードして直接呼べる。
#if __has_include("CSAApp-Swift.h")
#import "CSAApp-Swift.h"
#endif

using namespace cv;

// OpenCV をインクルードするために一時的に NO を undef しているため、
// ここで Objective-C の YES/NO マクロを再定義しておく
#ifndef YES
#define YES ((BOOL)1)
#endif
#ifndef NO
#define NO ((BOOL)0)
#endif

@implementation OpenCVWrapper
// 共通ユーティリティ（クラスメソッド）: 画像リサイズ
+ (cv::Mat)resizeImage:(cv::Mat)src
                scaleX:(double)scaleX
                scaleY:(double)scaleY
         interpolation:(int)interpolation {
  cv::Mat resized;
  cv::resize(src, resized, cv::Size(), scaleX, scaleY, interpolation);
  return resized;
}

// 共通ユーティリティ（クラスメソッド）: グレースケール化 引数: srcMat(in) ->
// grayscale を返す
+ (cv::Mat)toGrayFromMat:(cv::Mat)srcMat {
  cv::Mat gray;
  if (srcMat.channels() == 4) {
    cv::cvtColor(srcMat, gray, cv::COLOR_RGBA2GRAY);
  } else if (srcMat.channels() == 3) {
    cv::cvtColor(srcMat, gray, cv::COLOR_BGR2GRAY);
  } else {
    gray = srcMat.clone();
  }
  return gray;
}

// 共通ユーティリティ（クラスメソッド）: Gaussian Blur を簡潔に呼ぶラッパ
+ (cv::Mat)gaussianBlurMat:(cv::Mat)src ksize:(int)ksigma sigma:(double)sigma {
  cv::Mat out;
  int k = ksigma;
  if (k % 2 == 0)
    k = std::max(1, k - 1);
  cv::GaussianBlur(src, out, cv::Size(k, k), sigma);
  return out;
}

// 共通ユーティリティ（クラスメソッド）: 二値化
// adaptiveThreshold を試し、失敗なら Otsu にフォールバック
+ (cv::Mat)adaptiveOrOtsuThreshold:(cv::Mat)gray
                         blockSize:(int)blockSize
                                 C:(int)C {
  cv::Mat binary;
  int b = blockSize;
  if (b % 2 == 0)
    b = std::max(3, b - 1);
  cv::adaptiveThreshold(gray, binary, 255, cv::ADAPTIVE_THRESH_MEAN_C,
                        cv::THRESH_BINARY, b, C);
  double nonZero = cv::countNonZero(binary);
  if (nonZero == 0 || nonZero == binary.rows * binary.cols) {
    cv::threshold(gray, binary, 0, 255, cv::THRESH_OTSU);
  }
  return binary;
}

// 共通ユーティリティ（クラスメソッド）:
// Gaussian適応的二値化（カスタムパラメータ対応）
// (adaptive Gaussian threshold wrapper)
+ (cv::Mat)adaptiveThresholdGaussian:(cv::Mat)gray
                           blockSize:(int)blockSize
                                   C:(int)C {
  cv::Mat binary;
  int b = blockSize;
  if (b % 2 == 0)
    b = std::max(3, b - 1);
  cv::adaptiveThreshold(gray, binary, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                        cv::THRESH_BINARY, b, C);
  return binary;
}

// 共通ユーティリティ（クラスメソッド）: 画像の白黒反転
+ (cv::Mat)invertImage:(cv::Mat)src {
  cv::Mat inverted;
  cv::bitwise_not(src, inverted);
  return inverted;
}

// 共通ユーティリティ（クラスメソッド）: 統一画像前処理（フル版）
// UIImage → cv::Mat変換 + 空画像チェック + グレースケール変換 + 元のmat取得
+ (cv::Mat)prepareImageForProcessing:(UIImage *)image
                           errorCode:(NSString **)errorCode
                          methodName:(NSString *)methodName
                         originalMat:(cv::Mat *)originalMat {
  // エラーコードを初期化
  if (errorCode) {
    *errorCode = nil;
  }

  // 入力チェック
  if (image == nil) {
    NSLog(@"OpenCVWrapper: %@ - 無効な入力", methodName);
    if (errorCode) {
      *errorCode = @"invalid_input";
    }
    return cv::Mat();
  }

  // UIImage を cv::Mat に変換
  cv::Mat mat;
  UIImageToMat(image, mat);

  // 空の画像チェック
  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: %@ - 空の画像", methodName);
    if (errorCode) {
      *errorCode = @"empty_image";
    }
    return cv::Mat();
  }

  // 元のmatを出力パラメータに設定
  if (originalMat) {
    *originalMat = mat;
  }

  // グレースケール変換
  cv::Mat gray = [self toGrayFromMat:mat];

  NSLog(@"OpenCVWrapper: %@ - 画像前処理完了 (%dx%d)", methodName, gray.cols,
        gray.rows);

  return gray;
}

// 共通ユーティリティ（クラスメソッド）: OCR用高精度画像前処理（基本版）
// UIImage → cv::Mat変換 + 空画像チェック + OCR最適化処理一式
+ (cv::Mat)prepareImageForOCRProcessing:(UIImage *)image
                              errorCode:(NSString **)errorCode
                             methodName:(NSString *)methodName {
  return [OpenCVWrapper prepareImageForOCRProcessing:image
                                           errorCode:errorCode
                                          methodName:methodName
                                         originalMat:nil];
}

// 共通ユーティリティ（クラスメソッド）: OCR用高精度画像前処理（cv::Mat版）
// cv::Mat（ROI）→ OCR最適化処理一式
// 名前を明確化: cv::Mat 入力向けのオーバーロードは混同を避けるため
// prepareImageForOCRProcessingFromMat: に変更
+ (cv::Mat)prepareImageForOCRProcessingFromMat:(cv::Mat)mat {
  // 空の画像チェック
  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: prepareImageForOCRProcessing(Mat) - 空の画像");
    return cv::Mat();
  }

  // OCR用高精度前処理を適用
  cv::Mat processed = mat.clone();

  // 1. グレースケール変換
  if (processed.channels() > 1) {
    processed = [OpenCVWrapper toGrayFromMat:processed];
  }

  // 2. 画像拡大（文字の詳細を保持）
  processed = [OpenCVWrapper resizeImage:processed
                                  scaleX:2.0
                                  scaleY:2.0
                           interpolation:cv::INTER_CUBIC];

  // 3. コントラスト強化
  processed = [OpenCVWrapper enhanceContrastCLAHE:processed clipLimit:3.0];

  // 4. ノイズ除去（軽め）
  processed = [OpenCVWrapper gaussianBlurMat:processed ksize:3 sigma:0.8];

  // 5. シャープニング（文字のエッジを強調）
  processed = [OpenCVWrapper sharpenImage:processed strength:0.5];

  // 6. 適応的二値化（OCR最適化パラメータ）
  processed = [OpenCVWrapper adaptiveThresholdGaussian:processed
                                             blockSize:15
                                                     C:8];

  // 7. 文字最適化モルフォロジー処理
  processed = [OpenCVWrapper optimizeTextMorphology:processed
                                         dilateSize:1
                                          erodeSize:1];

  NSLog(@"OpenCVWrapper: prepareImageForOCRProcessingFromMat - "
        @"OCR用高精度前処理完了 (%dx%d)",
        processed.cols, processed.rows);

  return processed;
}

// 共通ユーティリティ（クラスメソッド）: OCR用高精度画像前処理（フル版）
// UIImage → cv::Mat変換 + 空画像チェック + OCR最適化処理一式 + 元のmat取得
+ (cv::Mat)prepareImageForOCRProcessing:(UIImage *)image
                              errorCode:(NSString **)errorCode
                             methodName:(NSString *)methodName
                            originalMat:(cv::Mat *)originalMat {
  // エラーコードを初期化
  if (errorCode) {
    *errorCode = nil;
  }

  // 入力チェック
  if (image == nil) {
    NSLog(@"OpenCVWrapper: %@ - 無効な入力", methodName);
    if (errorCode) {
      *errorCode = @"invalid_input";
    }
    return cv::Mat();
  }

  // UIImage を cv::Mat に変換
  cv::Mat mat;
  UIImageToMat(image, mat);

  // 空の画像チェック
  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: %@ - 空の画像", methodName);
    if (errorCode) {
      *errorCode = @"empty_image";
    }
    return cv::Mat();
  }

  // 元のmatを出力パラメータに設定
  if (originalMat) {
    *originalMat = mat;
  }

  // OCR用高精度前処理を適用
  cv::Mat processed = mat.clone();

  // 1. グレースケール変換
  if (processed.channels() > 1) {
    processed = [OpenCVWrapper toGrayFromMat:processed];
  }

  // 2. 画像拡大（文字の詳細を保持）
  processed = [OpenCVWrapper resizeImage:processed
                                  scaleX:2.0
                                  scaleY:2.0
                           interpolation:cv::INTER_CUBIC];

  // 3. コントラスト強化
  processed = [OpenCVWrapper enhanceContrastCLAHE:processed clipLimit:3.0];

  // 4. ノイズ除去（軽め）
  processed = [OpenCVWrapper gaussianBlurMat:processed ksize:3 sigma:0.8];

  // 5. シャープニング（文字のエッジを強調）
  processed = [OpenCVWrapper sharpenImage:processed strength:0.5];

  // 6. 適応的二値化（OCR最適化パラメータ）
  processed = [OpenCVWrapper adaptiveThresholdGaussian:processed
                                             blockSize:15
                                                     C:8];

  // 7. 文字最適化モルフォロジー処理
  processed = [OpenCVWrapper optimizeTextMorphology:processed
                                         dilateSize:1
                                          erodeSize:1];

  NSLog(@"OpenCVWrapper: %@ - OCR用高精度前処理完了 (%dx%d)", methodName,
        processed.cols, processed.rows);

  return processed;
}

// 共通ユーティリティ（クラスメソッド）:
// モルフォロジーによるノイズ除去（オープン処理）
+ (cv::Mat)morphologyDenoiseOpen:(cv::Mat)src kernelSize:(int)kernelSize {
  cv::Mat denoised;
  cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT,
                                             cv::Size(kernelSize, kernelSize));
  cv::morphologyEx(src, denoised, cv::MORPH_OPEN, kernel);
  return denoised;
}

// 共通ユーティリティ（クラスメソッド）: ヒストグラム均等化による最適化
+ (cv::Mat)enhanceContrastCLAHE:(cv::Mat)gray clipLimit:(double)clipLimit {
  cv::Mat enhanced;
  cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE();
  clahe->setClipLimit(clipLimit);
  clahe->apply(gray, enhanced);
  return enhanced;
}

// 共通ユーティリティ（クラスメソッド）: シャープニングフィルタ
+ (cv::Mat)sharpenImage:(cv::Mat)src strength:(double)strength {
  cv::Mat sharpened;
  cv::Mat kernel = (cv::Mat_<float>(3, 3) << 0, -strength, 0, -strength,
                    1 + 4 * strength, -strength, 0, -strength, 0);
  cv::filter2D(src, sharpened, -1, kernel);
  return sharpened;
}

// 共通ユーティリティ（クラスメソッド）: 文字最適化モルフォロジー処理
+ (cv::Mat)optimizeTextMorphology:(cv::Mat)binary
                       dilateSize:(int)dilateSize
                        erodeSize:(int)erodeSize {
  cv::Mat optimized;

  // わずかに膨張（文字の欠損を修復）
  if (dilateSize > 0) {
    cv::Mat dilateKernel = cv::getStructuringElement(
        cv::MORPH_RECT, cv::Size(dilateSize, dilateSize));
    cv::dilate(binary, optimized, dilateKernel);
  } else {
    optimized = binary.clone();
  }

  // 収縮で元のサイズに戻す（ノイズを除去）
  if (erodeSize > 0) {
    cv::Mat erodeKernel = cv::getStructuringElement(
        cv::MORPH_RECT, cv::Size(erodeSize, erodeSize));
    cv::erode(optimized, optimized, erodeKernel);
  }

  return optimized;
}

// 共通ユーティリティ（クラスメソッド）: 行/列方向の投影和を返す
+ (cv::Mat)projectionSum:(cv::Mat)binary axis:(int)axis {
  cv::Mat proj;
  cv::reduce(binary, proj, axis, cv::REDUCE_SUM, CV_32S);
  return proj;
}

// 共通ユーティリティ（クラスメソッド）: 近接する線位置 (int 配列) をマージする
+ (std::vector<int>)mergeCloseLines:(const std::vector<int> &)lines
                                gap:(int)gap {
  std::vector<int> merged;
  if (lines.empty())
    return merged;
  merged.push_back(lines[0]);
  for (size_t i = 1; i < lines.size(); i++) {
    if (lines[i] - merged.back() > gap)
      merged.push_back(lines[i]);
  }
  return merged;
}

// 主要機能（クラスメソッド）: テンプレートマッチングによる設問画像の切り取り
+ (NSDictionary *)processImageWithTemplateMatchingAndCrop:(UIImage *)image {
  // 統一前処理を適用（元のmatも取得）
  NSString *errorCode = nil;
  cv::Mat mat;
  cv::Mat initialGray =
      [self prepareImageForProcessing:image
                            errorCode:&errorCode
                           methodName:@"processImageWithTemplateMatchingAndCrop"
                          originalMat:&mat];

  if (errorCode) {
    return @{
      @"processedImage" : image ?: [NSNull null],
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  NSLog(@"OpenCVWrapper: 元画像 channels=%d, type=%d, size=%dx%d",
        mat.channels(), mat.type(), mat.cols, mat.rows);

  // === 画像処理部分 ===
  // 1. 画像を拡大（処理の精度向上のため）
  cv::Mat resizedMat;
  try {
    resizedMat = [OpenCVWrapper resizeImage:mat
                                     scaleX:2.0
                                     scaleY:2.0
                              interpolation:cv::INTER_LINEAR];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: resizeでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 2. グレースケール変換（拡大した画像から）
  cv::Mat grayMat;
  try {
    grayMat = [OpenCVWrapper toGrayFromMat:resizedMat];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: グレースケール変換でエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 3. ガウシアンブラーで平滑化（テンプレートマッチング用に調整）
  cv::Mat blurMat;
  try {
    blurMat = [OpenCVWrapper gaussianBlurMat:grayMat ksize:3 sigma:1.0];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: GaussianBlurでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 4. 適応的二値化（テンプレートマッチング用パラメータ）
  cv::Mat binaryMat;
  // 適応的二値化のパラメータを調整
  try {
    binaryMat = [OpenCVWrapper adaptiveThresholdGaussian:blurMat
                                               blockSize:25
                                                       C:5];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: adaptiveThresholdでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 白黒反転前にさらに平滑化処理を追加
  cv::Mat extraBlurMat;
  try {
    extraBlurMat = [OpenCVWrapper gaussianBlurMat:binaryMat ksize:5 sigma:2.0];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: extra GaussianBlurでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 5. 白黒反転
  cv::Mat invMat;
  try {
    invMat = [OpenCVWrapper invertImage:extraBlurMat];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: bitwise_notでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 6. ノイズ除去（モルフォロジーオープン）
  cv::Mat noNoiseMat;
  try {
    noNoiseMat = [OpenCVWrapper morphologyDenoiseOpen:invMat kernelSize:3];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: morphologyExでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 7. 再度反転
  cv::Mat finalMat;
  try {
    finalMat = [OpenCVWrapper invertImage:noNoiseMat];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: bitwise_not(2)でエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 処理済み画像をUIImageに変換
  UIImage *processedImage = nil;
  try {
    processedImage = MatToUIImage(finalMat);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: 処理済み画像変換でエラー: %s", e.what());
    processedImage = image;
  }

  // === テンプレートマッチング部分 ===
  // 元画像のグレースケール版を作成（テンプレートマッチング用）
  cv::Mat originalGrayMat;
  try {
    originalGrayMat = [OpenCVWrapper toGrayFromMat:mat];
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: 元画像グレースケール変換でエラー: %s", e.what());
    return @{
      @"processedImage" : processedImage ?: image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 軽いガウシアンブラーでノイズ除去
  cv::Mat blurredOriginalMat;
  blurredOriginalMat = [OpenCVWrapper gaussianBlurMat:originalGrayMat
                                                ksize:3
                                                sigma:1.0];

  // テンプレートマッチングによるマーカー検出 (q.png をテンプレートとして使用)
  std::vector<cv::Vec3f>
      markers; // (x, y, r) の配列として扱う（rは互換性のため残す）
  try {
    // テンプレート画像をバンドルから読み込む
    UIImage *tplUIImage = [UIImage imageNamed:@"q"];
    if (tplUIImage == nil) {
      // 直接ファイルを探す（fallback）
      NSString *path = [[NSBundle mainBundle] pathForResource:@"q"
                                                       ofType:@"png"];
      if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        tplUIImage = [UIImage imageWithContentsOfFile:path];
      }
    }

    if (tplUIImage == nil) {
      NSLog(@"OpenCVWrapper: テンプレート画像 q.png を読み込めませんでした");
      return @{
        @"processedImage" : [NSNull null],
        @"templateCenters" : @[],
        @"croppedImages" : @[]
      };
    }

    cv::Mat tplMat;
    UIImageToMat(tplUIImage, tplMat);
    if (tplMat.empty()) {
      NSLog(@"OpenCVWrapper: テンプレート画像が空です");
      return @{
        @"processedImage" : [NSNull null],
        @"templateCenters" : @[],
        @"croppedImages" : @[]
      };
    }

    // テンプレートもグレースケール化しておく
    cv::Mat tplGray;
    tplGray = [OpenCVWrapper toGrayFromMat:tplMat];

    // matchTemplate を実行（TM_CCOEFF_NORMED）
    cv::Mat result;
    cv::matchTemplate(blurredOriginalMat, tplGray, result,
                      cv::TM_CCOEFF_NORMED);

    // 閾値でピークを逐次検出していく
    const double threshold = 0.65; // 調整可能
    while (true) {
      double minVal, maxVal;
      cv::Point minLoc, maxLoc;
      cv::minMaxLoc(result, &minVal, &maxVal, &minLoc, &maxLoc);
      if (maxVal < threshold)
        break;

      // テンプレートの中心をマーカー中心とみなす
      float centerX = static_cast<float>(maxLoc.x) + tplGray.cols / 2.0f;
      float centerY = static_cast<float>(maxLoc.y) + tplGray.rows / 2.0f;
      float radius = std::max(tplGray.cols, tplGray.rows) / 2.0f;
      markers.push_back(cv::Vec3f(centerX, centerY, radius));

      // 検出領域を抑制して重複検出を防ぐ
      int x0 = std::max(0, maxLoc.x - tplGray.cols / 2);
      int y0 = std::max(0, maxLoc.y - tplGray.rows / 2);
      int x1 = std::min(result.cols - 1, maxLoc.x + tplGray.cols / 2);
      int y1 = std::min(result.rows - 1, maxLoc.y + tplGray.rows / 2);
      for (int y = y0; y <= y1; ++y) {
        for (int x = x0; x <= x1; ++x) {
          result.at<float>(y, x) = 0.0f;
        }
      }
    }

    NSLog(@"OpenCVWrapper: テンプレートマッチングで検出された個数: %zu",
          markers.size());
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: テンプレートマッチングでエラー: %s", e.what());
    return @{
      @"processedImage" : processedImage ?: image,
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // テンプレート検出結果がなければ終了
  if (markers.empty()) {
    NSLog(@"OpenCVWrapper: テンプレートマッチで何も検出されませんでした");
    return @{
      @"processedImage" : [NSNull null],
      @"templateCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 検出された中心点を NSArray に変換
  NSMutableArray<NSValue *> *templateCenters = [NSMutableArray array];
  for (const auto &marker : markers) {
    // cv::Vec3f の要素は float なので CGFloat にキャストする
    CGPoint center = CGPointMake((CGFloat)marker[0], (CGFloat)marker[1]);
    [templateCenters addObject:[NSValue valueWithCGPoint:center]];
  }

  // === 画像切り取り部分 ===
  NSMutableArray<UIImage *> *croppedImages = [NSMutableArray array];

  if (!markers.empty()) {
    // マーカーをy座標でソート（上から下へ）
    std::sort(
        markers.begin(), markers.end(),
        [](const cv::Vec3f &a, const cv::Vec3f &b) { return a[1] < b[1]; });

    NSLog(@"OpenCVWrapper: 切り取り領域計算開始");
    for (size_t i = 0; i < markers.size(); i++) {
      const auto &marker = markers[i];
      float centerX = marker[0];
      float centerY = marker[1];
      float radius = marker[2];

      // マーカーの左上の座標を始点とする
      int startX = static_cast<int>(centerX - radius);
      int startY = static_cast<int>(centerY - radius);

      // 画像の範囲内に調整
      startX = std::max(0, startX);
      startY = std::max(0, startY);

      // 横幅は画像の右端まで
      int width = mat.cols - startX;

      // 縦幅を計算：次のマーカーまでの距離、または画像の下端まで
      int height;
      if (i + 1 < markers.size()) {
        const auto &nextMarker = markers[i + 1];
        int nextMarkerTop = static_cast<int>(nextMarker[1] - nextMarker[2]);
        height = nextMarkerTop - startY;
      } else {
        height = mat.rows - startY;
      }

      // 縦幅が0以下の場合はスキップ
      if (height <= 0) {
        NSLog(@"OpenCVWrapper: マーカー%zu: 高さが不正 (%d)", i, height);
        continue;
      }

      // 画像の範囲内に調整
      height = std::min(height, mat.rows - startY);

      NSLog(@"OpenCVWrapper: マーカー%zu: 切り取り領域 x=%d, y=%d, w=%d, h=%d",
            i, startX, startY, width, height);

      try {
        cv::Rect cropRect(startX, startY, width, height);
        cv::Mat croppedMat = mat(cropRect);
        UIImage *croppedImage = MatToUIImage(croppedMat);
        if (croppedImage != nil) {
          [croppedImages addObject:croppedImage];
        }
      } catch (const cv::Exception &e) {
        NSLog(@"OpenCVWrapper: マーカー%zu: 切り取りでエラー: %s", i, e.what());
        continue;
      }
    }
  }

  // 切り取った画像がない場合は元の画像を返す
  if ([croppedImages count] == 0) {
    [croppedImages addObject:image];
  }

  NSLog(@"OpenCVWrapper: 処理完了 - 切り取った画像数: %lu",
        (unsigned long)[croppedImages count]);

  return @{
    @"processedImage" : processedImage ?: image,
    @"templateCenters" : templateCenters,
    @"croppedImages" : croppedImages
  };
}

// 切り取った設問画像ごとにStoredTypeとoptionTextsを受け取り、種類ごとに処理を振り分ける
// 使用StoredType: single, multiple, text, info (各要素を
// parseCroppedImagesが振り分け)
+ (NSDictionary *)parseCroppedImages:(UIImage *)image
                   withCroppedImages:(NSArray<UIImage *> *)croppedImages
                     withStoredTypes:(NSArray<NSString *> *)types
                     withOptionTexts:
                         (NSArray<NSArray<NSString *> *> *)optionTexts {
  // 引数チェック
  if (croppedImages == nil || [croppedImages count] == 0) {
    NSLog(@"OpenCVWrapper.parseCroppedImages: croppedImages が空です");
    return
        @{@"processedImage" : image ?: [NSNull null], @"parsedAnswers" : @[]};
  }

  size_t n = [croppedImages count];
  NSLog(@"OpenCVWrapper.parseCroppedImages: images=%zu, types=%zu, "
        @"optionTexts=%zu",
        n, (size_t)(types ? [types count] : 0),
        (size_t)(optionTexts ? [optionTexts count] : 0));

  // 全体の types と optionTexts を出力（デバッグ用）
  NSLog(@"OpenCVWrapper.parseCroppedImages: provided types=%@", types ?: @[]);
  NSLog(@"OpenCVWrapper.parseCroppedImages: provided optionTexts (count=%lu):",
        (unsigned long)(optionTexts ? [optionTexts count] : 0));

  // optionTexts の内容も個別に出力して文字化けを回避
  if (optionTexts) {
    for (NSUInteger idx = 0; idx < [optionTexts count]; idx++) {
      NSArray<NSString *> *optionsAtIndex = optionTexts[idx];
      NSLog(@"  optionTexts[%lu] (count=%lu):", (unsigned long)idx,
            (unsigned long)[optionsAtIndex count]);
      for (NSUInteger j = 0; j < [optionsAtIndex count]; j++) {
        NSLog(@"    [%lu]: %@", (unsigned long)j, optionsAtIndex[j]);
      }
    }
  }

  // 並列処理用に結果配列を事前に確保（スレッドセーフ）
  NSMutableArray<NSString *> *parsedAnswers =
      [NSMutableArray arrayWithCapacity:n];
  for (size_t i = 0; i < n; i++) {
    [parsedAnswers addObject:@""]; // プレースホルダーで初期化
  }

  NSLog(@"OpenCVWrapper.parseCroppedImages: 並列処理開始 - %zu個の設問を処理",
        n);

  // 並列処理でループを実行（CPUコア数に応じて自動分散）
  dispatch_apply(
      n, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
      ^(size_t i) {
        NSString *storedType =
            (types && i < [types count]) ? types[i] : @"unknown";
        NSArray<NSString *> *optionArray =
            (optionTexts && i < [optionTexts count]) ? optionTexts[i] : @[];
        NSInteger optCount = [optionArray count];

        // 各要素ごとに storedType と対応する optionCount を明示的に出力
        // optionTexts の内容を個別に出力して文字化けを回避
        NSLog(@"OpenCVWrapper: [並列] index=%zu -> storedType=%@, "
              @"optionCount=%ld",
              i, storedType, (long)optCount);
        for (NSUInteger j = 0; j < [optionArray count]; j++) {
          NSString *option = optionArray[j];
          NSLog(@"  [並列] option[%lu]: %@", (unsigned long)j, option);
        }

        NSString *result = @"0"; // デフォルト値

        // StoredType ごとの分岐：実際のOpenCV処理を実装
        if ([storedType isEqualToString:@"single"]) {
          NSLog(@"OpenCVWrapper: [並列] index=%zu -> handling as SINGLE with "
                @"%ld options",
                i, (long)optCount);

          // チェックボックス検出処理を実行
          UIImage *croppedImage = croppedImages[i];
          result = [self detectSingleAnswerFromImage:croppedImage
                                         withOptions:optionArray];
        } else if ([storedType isEqualToString:@"multiple"]) {
          NSLog(@"OpenCVWrapper: [並列] index=%zu -> handling as MULTIPLE with "
                @"%ld options",
                i, (long)optCount);

          // 複数回答チェックボックス検出処理を実行
          UIImage *croppedImage = croppedImages[i];
          result = [self detectMultipleAnswerFromImage:croppedImage
                                           withOptions:optionArray];
        } else if ([storedType isEqualToString:@"text"]) {
          NSLog(@"OpenCVWrapper: [並列] index=%zu -> handling as TEXT", i);

          // テキスト検出処理を実行
          UIImage *croppedImage = croppedImages[i];
          result = [self detectTextAnswerFromImage:croppedImage];
        } else if ([storedType isEqualToString:@"info"]) {
          NSLog(@"OpenCVWrapper: [並列] index=%zu -> handling as INFO", i);

          // info設問専用の処理を実行
          UIImage *croppedImage = croppedImages[i];
          // optionArray に InfoField の rawValue (ex: "zip") が入っている想定
          result = [self detectInfoAnswerFromImage:croppedImage
                                   withOptionArray:optionArray];
        } else {
          NSLog(@"OpenCVWrapper: [並列] index=%zu -> handling as UNKNOWN", i);
          result = @"0";
        }

        // 結果を正しいインデックスに格納（スレッドセーフ）
        @synchronized(parsedAnswers) {
          parsedAnswers[i] = result;
        }

        NSLog(@"OpenCVWrapper: [並列] index=%zu 完了 -> result=%@", i, result);
      });

  NSLog(@"OpenCVWrapper.parseCroppedImages: 並列処理完了");

  return @{
    @"processedImage" : image ?: [NSNull null],
    @"parsedAnswers" : parsedAnswers
  };
}

// チェックボックス検出のヘルパーメソッド
// 使用StoredType: single
+ (NSString *)detectSingleAnswerFromImage:(UIImage *)image
                              withOptions:(NSArray<NSString *> *)options {
  if ([options count] == 0) {
    NSLog(@"OpenCVWrapper: detectSingleAnswer - オプションが空");
    return @"-1";
  }

  // 統一前処理を適用
  NSString *errorCode = nil;
  cv::Mat gray = [self prepareImageForProcessing:image
                                       errorCode:&errorCode
                                      methodName:@"detectSingleAnswer"
                                     originalMat:NULL];

  if (!errorCode && gray.empty()) {
    return @"-1";
  }
  if (errorCode) {
    return @"-1";
  }

  // チェックボックス検出処理
  std::vector<cv::Rect> checkboxes = [self detectCheckboxes:gray];

  if (checkboxes.empty()) {
    NSLog(@"OpenCVWrapper: detectSingleAnswer - "
          @"チェックボックスが見つかりません");
    return @"-1";
  }

  // チェック状態を確認
  int checkedIndex = -1;
  for (size_t i = 0; i < checkboxes.size() && i < [options count]; i++) {
    if ([self isCheckboxChecked:gray rect:checkboxes[i]]) {
      NSLog(@"OpenCVWrapper: detectSingleAnswer - チェック検出: index=%zu, "
            @"option=%@",
            i, options[i]);
      checkedIndex = (int)i;
      break; // 単数回答なので最初のチェックで終了
    }
  }

  // チェックが見つからない場合は「その他」の可能性をチェック
  if (checkedIndex == -1) {
    NSLog(@"OpenCVWrapper: detectSingleAnswer - "
          @"通常のチェックが見つからないため、その他を確認");

    // 選択肢に「その他」が含まれているかチェック
    BOOL hasOtherOption = false;
    int otherOptionIndex = -1;

    for (int i = 0; i < [options count]; i++) {
      NSString *option = options[i];
      if ([option containsString:@"その他"] ||
          [option containsString:@"そのた"] ||
          [option containsString:@"other"] ||
          [option containsString:@"Other"]) {
        hasOtherOption = true;
        otherOptionIndex = i;
        NSLog(@"OpenCVWrapper: detectSingleAnswer - 「その他」選択肢を発見: "
              @"index=%d, option=%@",
              i, option);
        break;
      }
    }

    if (hasOtherOption && otherOptionIndex >= 0 &&
        otherOptionIndex < checkboxes.size()) {
      // 「その他」の選択肢があり、対応するチェックボックスが存在するため、自由回答を検出
      NSLog(@"OpenCVWrapper: detectSingleAnswer - "
            @"「その他」の自由回答を検出試行中（チェックなし）");

      // 最後の選択肢（その他）のチェックボックス位置で自由記述を探す
      NSString *otherText = [self detectOtherFreeTextAtIndex:gray
                                                  checkboxes:checkboxes
                                                       index:otherOptionIndex];

      if (otherText && ![otherText isEqualToString:@""]) {
        NSLog(@"OpenCVWrapper: detectSingleAnswer - "
              @"チェックなしでその他の自由回答を検出: %@",
              otherText);
        return otherText;
      } else {
        NSLog(@"OpenCVWrapper: detectSingleAnswer - "
              @"「その他」の自由回答が見つからない");
      }
    } else {
      NSLog(@"OpenCVWrapper: detectSingleAnswer - "
            @"選択肢に「その他」がないか、対応するチェックボックスが見つからな"
            @"い");
    }
  } else {
    // チェックされた選択肢が「その他」かどうかを確認
    NSString *selectedOption = options[checkedIndex];
    BOOL isOtherOption = ([selectedOption containsString:@"その他"] ||
                          [selectedOption containsString:@"そのた"] ||
                          [selectedOption containsString:@"other"] ||
                          [selectedOption containsString:@"Other"]);

    if (isOtherOption) {
      NSLog(@"OpenCVWrapper: detectSingleAnswer - "
            @"選択された選択肢「%@」は「その他」のため、自由回答を検出",
            selectedOption);
      NSString *otherText = [self detectOtherFreeText:gray
                                           checkboxes:checkboxes];
      if (otherText && ![otherText isEqualToString:@""]) {
        NSLog(@"OpenCVWrapper: detectSingleAnswer - その他の自由回答を検出: %@",
              otherText);
        return otherText;
      }
    } else {
      NSLog(@"OpenCVWrapper: detectSingleAnswer - "
            @"選択された選択肢「%@」は通常の選択肢",
            selectedOption);
    }

    // 通常の選択肢の文章を返す（インデックスではなく）
    return selectedOption;
  }

  NSLog(@"OpenCVWrapper: detectSingleAnswer - チェックが見つかりません");
  return @"-1";
}

// 複数回答チェックボックス検出のヘルパーメソッド
// 使用StoredType: multiple
+ (NSString *)detectMultipleAnswerFromImage:(UIImage *)image
                                withOptions:(NSArray<NSString *> *)options {
  if ([options count] == 0) {
    NSLog(@"OpenCVWrapper: detectMultipleAnswer - オプションが空");
    return @"-1";
  }

  // 統一前処理を適用
  NSString *errorCode = nil;
  cv::Mat gray = [self prepareImageForProcessing:image
                                       errorCode:&errorCode
                                      methodName:@"detectMultipleAnswer"
                                     originalMat:NULL];

  if (!errorCode && gray.empty()) {
    return @"-1";
  }
  if (errorCode) {
    return @"-1";
  }

  // チェックボックス検出処理
  std::vector<cv::Rect> checkboxes = [self detectCheckboxes:gray];

  if (checkboxes.empty()) {
    NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
          @"チェックボックスが見つかりません");
    return @"-1";
  }

  // チェック状態を確認（複数回答なので全てチェック）
  NSMutableArray<NSString *> *checkedOptions = [NSMutableArray array];
  for (size_t i = 0; i < checkboxes.size() && i < [options count]; i++) {
    if ([self isCheckboxChecked:gray rect:checkboxes[i]]) {
      NSString *option = options[i];
      NSLog(@"OpenCVWrapper: detectMultipleAnswer - チェック検出: index=%zu, "
            @"option=%@",
            i, option);
      [checkedOptions addObject:option];
    }
  }

  // まず、選択肢に「その他」が含まれるインデックスを探す（存在するなら括弧内の文字列を検出しておく）
  NSString *otherText = nil;
  int otherOptionIndex = -1;
  for (int i = 0; i < [options count]; i++) {
    NSString *option = options[i];
    if ([option containsString:@"その他"] ||
        [option containsString:@"そのた"] || [option containsString:@"other"] ||
        [option containsString:@"Other"]) {
      otherOptionIndex = i;
      NSLog(@"OpenCVWrapper: detectMultipleAnswer - 「その他」選択肢を発見: "
            @"index=%d, option=%@",
            i, option);
      break;
    }
  }

  // 「その他」が選択肢にあれば、まず括弧内の文字列を検出する（single
  // と同じ方法を使用）
  if (otherOptionIndex >= 0 && otherOptionIndex < checkboxes.size()) {
    NSString *freeTextAtIndex =
        [self detectOtherFreeTextAtIndex:gray
                              checkboxes:checkboxes
                                   index:otherOptionIndex];
    if (freeTextAtIndex && ![freeTextAtIndex isEqualToString:@""]) {
      NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
            @"括弧内の自由回答を検出（その他候補）: %@",
            freeTextAtIndex);
      // チェックが一つもない場合は単独で返す（single と同様の振る舞い）
      if ([checkedOptions count] == 0) {
        return freeTextAtIndex;
      }
      // それ以外は後で結果に含めるため保持しておく
      otherText = freeTextAtIndex;
    }
  }

  // 次に、チェックされた選択肢の中に「その他」があり、かつ括弧内の文字列が空の場合は
  // チェックされたその他の近辺の自由回答領域を検出しておく（既存の検出方法を再利用）
  for (NSString *checkedOption in checkedOptions) {
    BOOL isOtherOption = ([checkedOption containsString:@"その他"] ||
                          [checkedOption containsString:@"そのた"] ||
                          [checkedOption containsString:@"other"] ||
                          [checkedOption containsString:@"Other"]);

    if (isOtherOption) {
      NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
            @"チェックされた選択肢に「その他」が含まれています: %@",
            checkedOption);
      // 既に括弧内テキストが見つかっていればそれを使う
      if (!otherText || [otherText isEqualToString:@""]) {
        NSString *freeText = [self detectOtherFreeText:gray
                                            checkboxes:checkboxes];
        if (freeText && ![freeText isEqualToString:@""]) {
          otherText = freeText;
          NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
                @"チェックされたその他から自由回答を検出: %@",
                otherText);
        }
      }
      break;
    }
  }

  // チェックが見つからない場合は、その他の括弧内テキストが既に検出されていればそれを返す
  if ([checkedOptions count] == 0) {
    if (otherText && ![otherText isEqualToString:@""]) {
      NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
            @"チェックなしだがその他の括弧内テキストを返す: %@",
            otherText);
      return otherText;
    }
    NSLog(@"OpenCVWrapper: detectMultipleAnswer - チェックが見つかりません");
    return @"-1";
  }

  // 結果を構築
  NSMutableArray<NSString *> *results = [NSMutableArray array];

  // チェックされた通常の選択肢を追加
  for (NSString *checkedOption in checkedOptions) {
    BOOL isOtherOption = ([checkedOption containsString:@"その他"] ||
                          [checkedOption containsString:@"そのた"] ||
                          [checkedOption containsString:@"other"] ||
                          [checkedOption containsString:@"Other"]);

    if (isOtherOption && otherText) {
      // 「その他」の場合は自由回答テキストを使用
      [results addObject:otherText];
    } else {
      // 通常の選択肢
      [results addObject:checkedOption];
    }
  }

  // 複数の選択肢を「,」で区切って返す
  // もし括弧内の自由回答が検出されていて results に含まれていなければ追加する
  if (otherText && ![otherText isEqualToString:@""] &&
      ![results containsObject:otherText]) {
    [results addObject:otherText];
  }

  NSString *finalResult = [results componentsJoinedByString:@","];
  NSLog(@"OpenCVWrapper: detectMultipleAnswer - 最終結果: %@", finalResult);
  return finalResult;
}

// チェックボックス矩形検出
// 使用StoredType: single, multiple
+ (std::vector<cv::Rect>)detectCheckboxes:(cv::Mat)gray {
  std::vector<cv::Rect> checkboxes;

  try {
    // https://stackoverflow.com/questions/63084676/checkbox-detection-opencv
    // 上の方法を参考に実装
    // Step 1: 二値化（共通ラッパを使用。固定180閾値より柔軟）
    cv::Mat binary = [self adaptiveOrOtsuThreshold:gray blockSize:15 C:5];

    // Step 2: 水平線と垂直線の検出
    int lWidth = 2;
    int lineMinWidth = 15;

    // カーネル定義
    cv::Mat kernel1h =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(lWidth, 1));
    cv::Mat kernel1v =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, lWidth));
    cv::Mat kernel6h =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(lineMinWidth, 1));
    cv::Mat kernel6v =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, lineMinWidth));

    // 水平線検出
    cv::Mat binaryInv;
    cv::bitwise_not(binary, binaryInv);

    cv::Mat imgBinH;
    cv::morphologyEx(binaryInv, imgBinH, cv::MORPH_CLOSE, kernel1h);
    cv::morphologyEx(imgBinH, imgBinH, cv::MORPH_OPEN, kernel6h);

    // 垂直線検出
    cv::Mat imgBinV;
    cv::morphologyEx(binaryInv, imgBinV, cv::MORPH_CLOSE, kernel1v);
    cv::morphologyEx(imgBinV, imgBinV, cv::MORPH_OPEN, kernel6v);

    // 水平線と垂直線を結合
    cv::Mat imgBinFinal;
    cv::bitwise_or(imgBinH, imgBinV, imgBinFinal);

    // 結果を修正（text.txtのfix関数相当）
    imgBinFinal.setTo(255, imgBinFinal > 127);
    imgBinFinal.setTo(0, imgBinFinal <= 127);

    // Step 4: 連結成分で矩形検出
    cv::Mat labels, stats, centroids;
    cv::bitwise_not(imgBinFinal, imgBinFinal);
    int numLabels =
        cv::connectedComponentsWithStats(imgBinFinal, labels, stats, centroids);

    // 矩形をサイズでフィルタリング（チェックボックスサイズに合うもの）
    for (int i = 1; i < numLabels; i++) {
      int x = stats.at<int>(i, cv::CC_STAT_LEFT);
      int y = stats.at<int>(i, cv::CC_STAT_TOP);
      int w = stats.at<int>(i, cv::CC_STAT_WIDTH);
      int h = stats.at<int>(i, cv::CC_STAT_HEIGHT);
      int area = stats.at<int>(i, cv::CC_STAT_AREA);

      // チェックボックスのサイズ判定（正方形に近く、適切なサイズ）
      if (w > 10 && h > 10 && w < 100 && h < 100 && abs(w - h) < 10 &&
          area > 100) {
        checkboxes.push_back(cv::Rect(x, y, w, h));
      }
    }

    // y座標でソート（上から下へ）、同じy座標なら左から右へ
    std::sort(checkboxes.begin(), checkboxes.end(),
              [](const cv::Rect &a, const cv::Rect &b) {
                if (abs(a.y - b.y) < 20) { // 同じ行とみなす
                  return a.x < b.x;
                }
                return a.y < b.y;
              });

    NSLog(@"OpenCVWrapper: detectCheckboxes - %zu個のチェックボックスを検出",
          checkboxes.size());

  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: detectCheckboxes でエラー: %s", e.what());
  }

  return checkboxes;
}

// チェックボックスがチェックされているかを判定
// 使用StoredType: single, multiple
+ (BOOL)isCheckboxChecked:(cv::Mat)gray rect:(cv::Rect)rect {
  try {
    // チェックボックス領域を抽出
    cv::Mat roi = gray(rect);

    // 二値化
    cv::Mat binary = [self adaptiveOrOtsuThreshold:roi blockSize:15 C:5];

    // 黒いピクセルの割合を計算
    int totalPixels = roi.rows * roi.cols;
    int blackPixels = totalPixels - cv::countNonZero(binary);
    double blackRatio = (double)blackPixels / totalPixels;

    // 閾値以上の黒いピクセルがあればチェック済みと判定
    bool isChecked = blackRatio > 0.1; // 10%以上が黒ならチェック済み

    NSLog(@"OpenCVWrapper: チェックボックス判定 - 黒ピクセル率: %.2f%%, "
          @"チェック済み: %s",
          blackRatio * 100, isChecked ? "YES" : "NO");

    return isChecked;

  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: isCheckboxChecked でエラー: %s", e.what());
    return false;
  }
}

// その他の自由回答テキストを検出
// 使用StoredType: single, multiple
+ (NSString *)detectOtherFreeText:(cv::Mat)gray
                       checkboxes:(std::vector<cv::Rect>)checkboxes {
  @try {
    if (checkboxes.empty()) {
      NSLog(@"OpenCVWrapper: detectOtherFreeText - "
            @"チェックボックスが見つかりません");
      return @"";
    }

    // 最後のチェックボックス（その他）を取得
    cv::Rect lastCheckbox = checkboxes.back();
    NSLog(@"OpenCVWrapper: detectOtherFreeText - 最後のチェックボックス位置: "
          @"x=%d, y=%d, w=%d, h=%d",
          lastCheckbox.x, lastCheckbox.y, lastCheckbox.width,
          lastCheckbox.height);

    // その他のチェックボックスから3つ分右の座標を計算
    // チェックボックス幅の3倍分右にオフセット
    int textStartX = lastCheckbox.x + (lastCheckbox.width * 3);
    int textY = lastCheckbox.y - 5; // 上に少し
    int textHeight =
        lastCheckbox.height + 10; // チェックボックスの高さに少し余裕を加える
    int textWidth = gray.cols - textStartX - 10; // 右端まで（余裕を持って）

    // 範囲チェック
    if (textStartX >= gray.cols || textY < 0 ||
        textY + textHeight >= gray.rows || textWidth <= 0) {
      NSLog(
          @"OpenCVWrapper: detectOtherFreeText - テキスト領域が画像範囲外です");
      return @"";
    }

    // テキスト領域を切り取り
    cv::Rect textRect(textStartX, textY, textWidth, textHeight);
    cv::Mat textROI = gray(textRect);

    // 統一されたOCR前処理を適用（cv::Matオーバーロードを使用）
    cv::Mat processedTextROI =
        [OpenCVWrapper prepareImageForOCRProcessingFromMat:textROI];
    NSLog(@"OpenCVWrapper: detectOtherFreeText - テキスト領域: x=%d, y=%d, "
          @"w=%d, h=%d (OCR前処理適用済み)",
          textRect.x, textRect.y, textRect.width, textRect.height);

    // ROIをUIImageに変換してVisionで文字認識
    UIImage *textImage = MatToUIImage(processedTextROI);

    // Vision APIを使用して文字認識
    NSString *recognizedText = [self recognizeTextFromImage:textImage];

    if (recognizedText) {
      // 括弧を除去する処理
      NSString *cleanedText = [self removeParenthesesFromText:recognizedText];

#if __has_include("CSAApp-Swift.h")
      // Swift の OCRManager が利用可能ならまずそちらを試す
      @try {
        // ROI を UIImage として渡し、信頼度を含む結果を取得
        NSDictionary *swiftResult = [OCRManager recognizeText:textImage
                                                     question:nil
                                                   storedType:nil
                                                   infoFields:nil];
        NSString *text = swiftResult[@"text"];
        NSNumber *confidence = swiftResult[@"confidence"];

        if (text && text.length > 0) {
          NSLog(@"OpenCVWrapper: recognizeTextFromImage - Swift OCRManager "
                @"結果: '%@' (信頼度: %.1f%%)",
                text, confidence.floatValue);
          return text;
        }
      } @catch (NSException *ex) {
        // Swift 呼び出しで問題があればフォールバックして Vision を実行
        NSLog(@"OpenCVWrapper: recognizeTextFromImage - OCRManager "
              @"呼び出し例外: %@",
              ex.reason);
      }
#endif

      // Swift 経由が空の場合は Vision の結果（cleanedText）を使う
      NSLog(@"OpenCVWrapper: detectOtherFreeText - 認識されたテキスト: '%@' -> "
            @"クリーンアップ後: '%@'",
            recognizedText, cleanedText);
      return cleanedText;
    }

    return @"";

  } @catch (NSException *exception) {
    NSLog(@"OpenCVWrapper: detectOtherFreeText でエラー: %@", exception.reason);
    return @"";
  }
}

// 指定したインデックスのチェックボックスでその他の自由回答テキストを検出
// 使用StoredType: single, multiple
+ (NSString *)detectOtherFreeTextAtIndex:(cv::Mat)gray
                              checkboxes:(std::vector<cv::Rect>)checkboxes
                                   index:(int)index {
  @try {
    if (checkboxes.empty() || index < 0 || index >= checkboxes.size()) {
      NSLog(@"OpenCVWrapper: detectOtherFreeTextAtIndex - "
            @"無効なインデックスまたは空のチェックボックス配列: index=%d, "
            @"size=%zu",
            index, checkboxes.size());
      return @"";
    }

    // 指定したインデックスのチェックボックスを取得
    cv::Rect targetCheckbox = checkboxes[index];
    NSLog(@"OpenCVWrapper: detectOtherFreeTextAtIndex - "
          @"ターゲットチェックボックス位置: "
          @"x=%d, y=%d, w=%d, h=%d (index=%d)",
          targetCheckbox.x, targetCheckbox.y, targetCheckbox.width,
          targetCheckbox.height, index);

    // その他のチェックボックスから3つ分右の座標を計算
    // チェックボックス幅の3倍分右にオフセット
    int textStartX = targetCheckbox.x + (targetCheckbox.width * 3);
    int textY = targetCheckbox.y - 5; // 上に少し
    int textHeight =
        targetCheckbox.height + 10; // チェックボックスの高さに少し余裕を加える
    int textWidth = gray.cols - textStartX - 10; // 右端まで（余裕を持って）

    // 範囲チェック
    if (textStartX >= gray.cols || textY < 0 ||
        textY + textHeight >= gray.rows || textWidth <= 0) {
      NSLog(@"OpenCVWrapper: detectOtherFreeTextAtIndex - "
            @"テキスト領域が画像範囲外です");
      return @"";
    }

    // テキスト領域を切り取り
    cv::Rect textRect(textStartX, textY, textWidth, textHeight);
    cv::Mat textROI = gray(textRect);

    // 統一されたOCR前処理を適用（cv::Matオーバーロードを使用）
    cv::Mat processedTextROI =
        [OpenCVWrapper prepareImageForOCRProcessingFromMat:textROI];
    NSLog(@"OpenCVWrapper: detectOtherFreeTextAtIndex - テキスト領域: x=%d, "
          @"y=%d, "
          @"w=%d, h=%d (OCR前処理適用済み)",
          textRect.x, textRect.y, textRect.width, textRect.height);

    // ROIをUIImageに変換してVisionで文字認識
    UIImage *textImage = MatToUIImage(processedTextROI);

    // Vision APIを使用して文字認識
    NSString *recognizedText = [self recognizeTextFromImage:textImage];

    if (recognizedText) {
      // 括弧内の文字列のみを抽出する処理
      NSString *extractedText =
          [self extractTextFromParentheses:recognizedText];
      NSLog(@"OpenCVWrapper: detectOtherFreeTextAtIndex - 認識されたテキスト: "
            @"'%@' -> "
            @"括弧内抽出後: '%@'",
            recognizedText, extractedText);
      return extractedText;
    }

    return @"";

  } @catch (NSException *exception) {
    NSLog(@"OpenCVWrapper: detectOtherFreeTextAtIndex でエラー: %@",
          exception.reason);
    return @"";
  }
}

// 括弧を除去するヘルパーメソッド
+ (NSString *)removeParenthesesFromText:(NSString *)text {
  if (!text || [text length] == 0) {
    return @"";
  }

  // 括弧とその中身を除去する正規表現
  NSError *error = nil;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"[（）()\\[\\]]"
                           options:NSRegularExpressionCaseInsensitive
                             error:&error];
  if (error) {
    NSLog(@"OpenCVWrapper: removeParenthesesFromText - 正規表現エラー: %@",
          error.localizedDescription);
    return text;
  }

  NSString *result =
      [regex stringByReplacingMatchesInString:text
                                      options:0
                                        range:NSMakeRange(0, [text length])
                                 withTemplate:@""];

  // 前後の空白を削除
  return [result
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
}

// 括弧内の文字列のみを抽出するヘルパーメソッド
+ (NSString *)extractTextFromParentheses:(NSString *)text {
  if (!text || [text length] == 0) {
    return @"";
  }

  // 「（」の位置を探す（日本語の括弧と英語の括弧の両方に対応）
  NSRange openParenRange = [text rangeOfString:@"（"];
  if (openParenRange.location == NSNotFound) {
    openParenRange = [text rangeOfString:@"("];
  }

  if (openParenRange.location == NSNotFound) {
    // 括弧が見つからない場合は空文字を返す
    NSLog(@"OpenCVWrapper: extractTextFromParentheses - "
          @"開き括弧が見つかりません: '%@'",
          text);
    return @"";
  }

  // 「（」以降の文字列を取得
  NSUInteger startIndex = openParenRange.location + openParenRange.length;
  if (startIndex >= [text length]) {
    NSLog(@"OpenCVWrapper: extractTextFromParentheses - "
          @"括弧の後に文字がありません: '%@'",
          text);
    return @"";
  }

  NSString *afterOpenParen = [text substringFromIndex:startIndex];

  // 「）」を除去する
  NSError *error = nil;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"[）)]"
                           options:NSRegularExpressionCaseInsensitive
                             error:&error];
  if (error) {
    NSLog(@"OpenCVWrapper: extractTextFromParentheses - 正規表現エラー: %@",
          error.localizedDescription);
    return afterOpenParen;
  }

  NSString *result = [regex
      stringByReplacingMatchesInString:afterOpenParen
                               options:0
                                 range:NSMakeRange(0, [afterOpenParen length])
                          withTemplate:@""];

  // 前後の空白を削除
  NSString *trimmedResult = [result
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];

  NSLog(@"OpenCVWrapper: extractTextFromParentheses - "
        @"元テキスト: '%@' -> 抽出結果: '%@'",
        text, trimmedResult);

  return trimmedResult;
}

// Vision APIを使用した文字認識
+ (NSString *)recognizeTextFromImage:(UIImage *)image {
  if (!image) {
    NSLog(@"OpenCVWrapper: recognizeTextFromImage - 画像がnilです");
    return @"";
  }

#if __has_include("CSAApp-Swift.h")
  // まず Swift 側の OCRManager を試みる（LLM 校正のパスに到達させるため）
  @try {
    NSDictionary *swiftResult = [OCRManager recognizeText:image
                                                 question:nil
                                               storedType:nil
                                               infoFields:nil];
    NSString *text = swiftResult[@"text"];
    NSNumber *confidence = swiftResult[@"confidence"];

    if (text && text.length > 0) {
      NSLog(@"OpenCVWrapper: recognizeTextFromImage - Swift OCRManager 結果: "
            @"'%@' (信頼度: %.1f%%)",
            text, confidence.floatValue);
      return text;
    } else {
      NSLog(@"OpenCVWrapper: recognizeTextFromImage - Swift OCRManager "
            @"は空の結果を返しました");
    }
  } @catch (NSException *ex) {
    NSLog(
        @"OpenCVWrapper: recognizeTextFromImage - OCRManager 呼び出し例外: %@",
        ex.reason);
  }
#endif

  __block NSString *recognizedText = @"";
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

  // Vision API用のリクエストを作成
  VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc]
      initWithCompletionHandler:^(VNRequest *request, NSError *error) {
        if (error) {
          NSLog(@"OpenCVWrapper: recognizeTextFromImage - Visionエラー: %@",
                error.localizedDescription);
          dispatch_semaphore_signal(semaphore);
          return;
        }

        // 認識結果を処理
        NSMutableArray *textParts = [NSMutableArray array];
        for (VNRecognizedTextObservation *observation in request.results) {
          VNRecognizedText *candidate =
              [observation topCandidates:1].firstObject;
          if (candidate && candidate.string.length > 0) {
            [textParts addObject:candidate.string];
          }
        }

        recognizedText = [textParts componentsJoinedByString:@" "];
        NSLog(@"OpenCVWrapper: recognizeTextFromImage - 認識結果: '%@'",
              recognizedText);
        dispatch_semaphore_signal(semaphore);
      }];

  // 認識レベルを設定（より高精度に）
  request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;

  // 日本語を認識対象に含める
  if (@available(iOS 13.0, *)) {
    request.recognitionLanguages = @[ @"ja", @"en" ];
  }

  // リクエストを実行
  VNImageRequestHandler *handler =
      [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage options:@{}];

  NSError *error = nil;
  BOOL success = [handler performRequests:@[ request ] error:&error];

  if (!success || error) {
    NSLog(@"OpenCVWrapper: recognizeTextFromImage - リクエスト実行エラー: %@",
          error ? error.localizedDescription : @"不明なエラー");
    dispatch_semaphore_signal(semaphore);
  }

  // 結果を待機（タイムアウト5秒）
  dispatch_time_t timeout =
      dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC);
  if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
    NSLog(@"OpenCVWrapper: recognizeTextFromImage - タイムアウトしました");
    return @"";
  }

  return recognizedText;
}

// テキスト回答検出のメソッド
// 使用StoredType: text
+ (NSString *)detectTextAnswerFromImage:(UIImage *)image {
  // 統一前処理を適用（matも取得する必要があるため、少し異なる処理）
  NSString *errorCode = nil;
  cv::Mat gray = [self prepareImageForProcessing:image
                                       errorCode:&errorCode
                                      methodName:@"detectTextAnswer"
                                     originalMat:NULL];

  if (errorCode) {
    return @"";
  }

  // 元のmatも必要なので再取得（座標計算とOCR前処理用）
  cv::Mat mat;
  UIImageToMat(image, mat);

  // 統一されたOCR前処理をUIImageから直接適用
  cv::Mat processedMat =
      [OpenCVWrapper prepareImageForOCRProcessing:image
                                        errorCode:&errorCode
                                       methodName:@"detectTextAnswer"
                                      originalMat:NULL];

  if (errorCode) {
    return @"";
  }

  // テキストボックス検出処理（グレースケール画像で検出）
  cv::Rect textBox = [self detectLargestTextBox:gray];

  if (textBox.width <= 0 || textBox.height <= 0) {
    NSLog(
        @"OpenCVWrapper: detectTextAnswer - テキストボックスが見つかりません");
    return @"";
  }

  // 前処理された画像から該当領域を抽出（座標をスケール調整）
  double scaleX = (double)processedMat.cols / mat.cols;
  double scaleY = (double)processedMat.rows / mat.rows;

  cv::Rect scaledTextBox;
  scaledTextBox.x = (int)(textBox.x * scaleX);
  scaledTextBox.y = (int)(textBox.y * scaleY);
  scaledTextBox.width = (int)(textBox.width * scaleX);
  scaledTextBox.height = (int)(textBox.height * scaleY);

  // 境界チェック
  scaledTextBox.x = std::max(0, scaledTextBox.x);
  scaledTextBox.y = std::max(0, scaledTextBox.y);
  scaledTextBox.width =
      std::min(scaledTextBox.width, processedMat.cols - scaledTextBox.x);
  scaledTextBox.height =
      std::min(scaledTextBox.height, processedMat.rows - scaledTextBox.y);

  cv::Mat textROI = processedMat(scaledTextBox);

  // ROIをUIImageに変換してVisionで文字認識
  UIImage *textImage = MatToUIImage(textROI);

  // Vision APIを使用して文字認識
  NSString *recognizedText = [self recognizeTextFromImage:textImage];

  if (recognizedText) {
    // 改行とスペースを削除して1行にする（正規化）
    NSString *cleanedText = [self normalizeOCRText:recognizedText
                                      removeSpaces:YES];
    NSLog(@"OpenCVWrapper: detectTextAnswer - 認識されたテキスト: '%@' -> "
          @"クリーンアップ後: '%@'",
          recognizedText, cleanedText);
    return cleanedText;
  }

  return @"";
}

// 最大のテキストボックスを検出するメソッド
// 使用StoredType: text
// 表の外側枠線を検出するヘルパーメソッド
+ (cv::Rect)detectTableOuterBounds:(cv::Mat)gray {
  cv::Rect outerBounds;

  try {
    // まずは既存のモルフォロジーに基づく検出を試みる
    // 二値化（共通ラッパを使用して adaptive->Otsu の挙動を統一）
    cv::Mat binary = [self adaptiveOrOtsuThreshold:gray blockSize:15 C:5];

    int lWidth = 2;
    int lineMinWidth = std::max(15, (int)(gray.cols * 0.02));

    cv::Mat kernel1h =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(lWidth, 1));
    cv::Mat kernel1v =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, lWidth));
    cv::Mat kernel6h =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(lineMinWidth, 1));
    cv::Mat kernel6v =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, lineMinWidth));

    cv::Mat binaryInv;
    cv::bitwise_not(binary, binaryInv);

    cv::Mat imgBinH;
    cv::morphologyEx(binaryInv, imgBinH, cv::MORPH_CLOSE, kernel1h);
    cv::morphologyEx(imgBinH, imgBinH, cv::MORPH_OPEN, kernel6h);

    cv::Mat imgBinV;
    cv::morphologyEx(binaryInv, imgBinV, cv::MORPH_CLOSE, kernel1v);
    cv::morphologyEx(imgBinV, imgBinV, cv::MORPH_OPEN, kernel6v);

    cv::Mat imgBinFinal;
    cv::bitwise_or(imgBinH, imgBinV, imgBinFinal);

    // 連結成分で矩形候補を検出
    cv::Mat labels, stats, centroids;
    cv::bitwise_not(imgBinFinal, imgBinFinal);
    int numLabels =
        cv::connectedComponentsWithStats(imgBinFinal, labels, stats, centroids);

    int maxArea = 0;
    for (int i = 1; i < numLabels; i++) {
      int x = stats.at<int>(i, cv::CC_STAT_LEFT);
      int y = stats.at<int>(i, cv::CC_STAT_TOP);
      int w = stats.at<int>(i, cv::CC_STAT_WIDTH);
      int h = stats.at<int>(i, cv::CC_STAT_HEIGHT);
      int area = stats.at<int>(i, cv::CC_STAT_AREA);

      bool isValidTableSize = (w > gray.cols * 0.25 && h > gray.rows * 0.25 &&
                               w < gray.cols * 0.98 && h < gray.rows * 0.98);
      bool isRectangular = ((double)w / (double)h > 0.6); // 幅/高さの比率緩和

      if (isValidTableSize && isRectangular && area > maxArea) {
        maxArea = area;
        outerBounds = cv::Rect(x, y, w, h);
      }
    }

    if (outerBounds.width > 0 && outerBounds.height > 0) {
      NSLog(@"OpenCVWrapper: detectTableOuterBounds - "
            @"morphology法で外枠を検出: x=%d, y=%d, w=%d, h=%d (area=%d)",
            outerBounds.x, outerBounds.y, outerBounds.width, outerBounds.height,
            maxArea);
      return outerBounds;
    }

    // morphology法で見つからなければ、Canny + findContours によるフォールバック
    NSLog(@"OpenCVWrapper: detectTableOuterBounds - "
          @"morphology法で外枠検出失敗、Cannyフォールバックを試行");

    cv::Mat edges;
    // コントラストが低い場合のために軽く平滑化
    cv::Mat smooth;
    cv::GaussianBlur(gray, smooth, cv::Size(3, 3), 0);
    cv::Canny(smooth, edges, 50, 150);

    // 膨張して線をつなげる
    cv::Mat dil;
    cv::dilate(edges, dil,
               cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3)));

    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(dil, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    NSLog(@"OpenCVWrapper: detectTableOuterBounds - findContours で %zu "
          @"個の輪郭を検出",
          contours.size());

    maxArea = 0;
    for (size_t i = 0; i < contours.size(); i++) {
      std::vector<cv::Point> approx;
      double peri = cv::arcLength(contours[i], true);
      cv::approxPolyDP(contours[i], approx, 0.02 * peri, true);

      cv::Rect r = cv::boundingRect(approx);
      int area = r.width * r.height;

      bool isLikelyTable =
          (r.width > gray.cols * 0.25 && r.height > gray.rows * 0.25 &&
           area > maxArea && r.width < gray.cols * 0.99 &&
           r.height < gray.rows * 0.99);

      if (isLikelyTable) {
        maxArea = area;
        outerBounds = r;
      }
    }

    if (outerBounds.width > 0 && outerBounds.height > 0) {
      NSLog(@"OpenCVWrapper: detectTableOuterBounds - Canny法で外枠を検出: "
            @"x=%d, y=%d, w=%d, h=%d (area=%d)",
            outerBounds.x, outerBounds.y, outerBounds.width, outerBounds.height,
            maxArea);
      return outerBounds;
    }

    NSLog(@"OpenCVWrapper: detectTableOuterBounds - "
          @"外枠が見つかりませんでした（両手法とも失敗）");

    // デバッグ用に中間画像を保存（閾値化・morphology結果・エッジ）
    try {
      NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
      [fmt setDateFormat:@"yyyyMMdd_HHmmss_SSS"];
      NSString *t = [fmt stringFromDate:[NSDate date]];

      // imgBinFinal が利用可能なら保存
      if (imgBinFinal.data && !imgBinFinal.empty()) {
        @try {
          UIImage *u = MatToUIImage(imgBinFinal);
          if (u) {
            NSString *p = [@"/tmp/CSA_debug_imgBinFinal_"
                stringByAppendingFormat:@"%@.png", t];
            NSData *d = UIImagePNGRepresentation(u);
            if (d)
              [d writeToFile:p atomically:YES];
            NSLog(@"OpenCVWrapper: detectTableOuterBounds - saved imgBinFinal "
                  @"to %@",
                  p);
          }
        } @catch (NSException *ex) {
          NSLog(@"OpenCVWrapper: detectTableOuterBounds - imgBinFinal save "
                @"exception: %@",
                ex);
        }
      }

      // edges が利用可能なら保存
      if (edges.data && !edges.empty()) {
        @try {
          UIImage *ue = MatToUIImage(edges);
          if (ue) {
            NSString *pe =
                [@"/tmp/CSA_debug_edges_" stringByAppendingFormat:@"%@.png", t];
            NSData *de = UIImagePNGRepresentation(ue);
            if (de)
              [de writeToFile:pe atomically:YES];
            NSLog(@"OpenCVWrapper: detectTableOuterBounds - saved edges to %@",
                  pe);
          }
        } @catch (NSException *ex) {
          NSLog(@"OpenCVWrapper: detectTableOuterBounds - edges save "
                @"exception: %@",
                ex);
        }
      }

      // dil（膨張画像）も保存しておく
      if (dil.data && !dil.empty()) {
        @try {
          UIImage *ud = MatToUIImage(dil);
          if (ud) {
            NSString *pd =
                [@"/tmp/CSA_debug_dil_" stringByAppendingFormat:@"%@.png", t];
            NSData *dd = UIImagePNGRepresentation(ud);
            if (dd)
              [dd writeToFile:pd atomically:YES];
            NSLog(@"OpenCVWrapper: detectTableOuterBounds - saved dil to %@",
                  pd);
          }
        } @catch (NSException *ex) {
          NSLog(
              @"OpenCVWrapper: detectTableOuterBounds - dil save exception: %@",
              ex);
        }
      }

    } catch (const cv::Exception &e) {
      NSLog(@"OpenCVWrapper: detectTableOuterBounds - debug save でエラー: %s",
            e.what());
    }

  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: detectTableOuterBounds でエラー: %s", e.what());
  }

  return outerBounds;
}

// 最大のテキストボックスを検出するメソッド
// 使用StoredType: text
+ (cv::Rect)detectLargestTextBox:(cv::Mat)gray {
  cv::Rect largestBox;

  try {
    // 二値化
    cv::Mat img = [self adaptiveOrOtsuThreshold:gray blockSize:15 C:5];

    // 水平線と垂直線の強調（テキスト領域を矩形で囲むため）
    int lWidth = 2;
    int lineMinWidth = std::max(15, (int)(gray.cols * 0.02));

    cv::Mat kernel1h =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(lWidth, 1));
    cv::Mat kernel1v =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, lWidth));
    cv::Mat kernel6h =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(lineMinWidth, 1));
    cv::Mat kernel6v =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, lineMinWidth));

    cv::Mat imgInv;
    cv::bitwise_not(img, imgInv);

    cv::Mat imgH;
    cv::morphologyEx(imgInv, imgH, cv::MORPH_CLOSE, kernel1h);
    cv::morphologyEx(imgH, imgH, cv::MORPH_OPEN, kernel6h);

    cv::Mat imgV;
    cv::morphologyEx(imgInv, imgV, cv::MORPH_CLOSE, kernel1v);
    cv::morphologyEx(imgV, imgV, cv::MORPH_OPEN, kernel6v);

    cv::Mat imgBinFinal;
    cv::bitwise_or(imgH, imgV, imgBinFinal);

    // 結果を2値化して安定化
    imgBinFinal.setTo(255, imgBinFinal > 127);
    imgBinFinal.setTo(0, imgBinFinal <= 127);

    // 連結成分解析で矩形候補を取得
    cv::Mat labels, stats, centroids;
    cv::bitwise_not(imgBinFinal, imgBinFinal);
    int numLabels =
        cv::connectedComponentsWithStats(imgBinFinal, labels, stats, centroids);

    int maxArea = 0;
    std::vector<cv::Rect> textBoxCandidates;

    for (int i = 1; i < numLabels; i++) {
      int x = stats.at<int>(i, cv::CC_STAT_LEFT);
      int y = stats.at<int>(i, cv::CC_STAT_TOP);
      int w = stats.at<int>(i, cv::CC_STAT_WIDTH);
      int h = stats.at<int>(i, cv::CC_STAT_HEIGHT);
      int area = stats.at<int>(i, cv::CC_STAT_AREA);

      bool isValidSize =
          (w > 50 && h > 20 && w < gray.cols * 0.9 && h < gray.rows * 0.9);
      bool isRectangular = (w > h * 1.5);
      bool hasReasonableArea =
          (area > 1000 && area < gray.cols * gray.rows * 0.8);
      bool notImageBorder =
          (x > 5 && y > 5 && x + w < gray.cols - 5 && y + h < gray.rows - 5);

      NSLog(@"OpenCVWrapper: detectLargestTextBox - label=%d "
            @"rect=(x=%d,y=%d,w=%d,h=%d) area=%d sizeOK=%d rectOK=%d areaOK=%d "
            @"borderOK=%d",
            i, x, y, w, h, area, isValidSize ? 1 : 0, isRectangular ? 1 : 0,
            hasReasonableArea ? 1 : 0, notImageBorder ? 1 : 0);

      if (isValidSize && isRectangular && hasReasonableArea && notImageBorder) {
        textBoxCandidates.push_back(cv::Rect(x, y, w, h));
        if (area > maxArea) {
          maxArea = area;
          largestBox = cv::Rect(x, y, w, h);
        }
      }
    }

    NSLog(@"OpenCVWrapper: detectLargestTextBox - %zu candidates, maxArea=%d",
          textBoxCandidates.size(), maxArea);

    // 画像全体に近い矩形の場合は警告
    if (largestBox.width > 0 && largestBox.height > 0) {
      if (largestBox.width >= gray.cols * 0.95 &&
          largestBox.height >= gray.rows * 0.95) {
        NSLog(@"OpenCVWrapper: detectLargestTextBox - Warning: largest box "
              @"close to whole image (w=%d,h=%d, img=%dx%d)",
              largestBox.width, largestBox.height, gray.cols, gray.rows);
      }
    }

  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: detectLargestTextBox でエラー: %s", e.what());
  }

  return largestBox;
}

// 改行を除去するヘルパーメソッド
// 使用StoredType: text, info
+ (NSString *)removeNewlinesFromText:(NSString *)text {
  if (!text || [text length] == 0) {
    return @"";
  }

  // 改行文字を空白に置換
  NSString *result = [text stringByReplacingOccurrencesOfString:@"\n"
                                                     withString:@" "];
  result = [result stringByReplacingOccurrencesOfString:@"\r" withString:@" "];

  // 複数の空白を1つの空白に統合
  NSError *error = nil;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"\\s+"
                           options:NSRegularExpressionCaseInsensitive
                             error:&error];
  if (!error) {
    result =
        [regex stringByReplacingMatchesInString:result
                                        options:0
                                          range:NSMakeRange(0, [result length])
                                   withTemplate:@" "];
  }

  // 前後の空白を削除
  return [result
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
}

// OCR の認識結果を正規化する共通メソッド
// removeSpaces が YES の場合は全ての空白（スペース/タブ）と改行を削除する
// NO
// の場合は改行のみをスペースに置換して連続空白を1つにする（既存の挙動に近い）
+ (NSString *)normalizeOCRText:(NSString *)text
                  removeSpaces:(BOOL)removeSpaces {
  if (!text || [text length] == 0) {
    return @"";
  }

  NSString *result = text;
  if (removeSpaces) {
    // 改行と復帰を削除
    result = [result stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    result = [result stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    // タブも削除
    result = [result stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    // 全角スペースと半角スペースを削除
    result = [result stringByReplacingOccurrencesOfString:@" " withString:@""];
    result = [result stringByReplacingOccurrencesOfString:@"\u3000"
                                               withString:@""];

    // 前後の空白をトリム（念のため）
    result = [result
        stringByTrimmingCharactersInSet:[NSCharacterSet
                                            whitespaceAndNewlineCharacterSet]];
    return result;
  } else {
    // 改行をスペースに置換し、連続空白を1つにする
    result = [result stringByReplacingOccurrencesOfString:@"\n"
                                               withString:@" "];
    result = [result stringByReplacingOccurrencesOfString:@"\r"
                                               withString:@" "];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"\\s+"
                             options:NSRegularExpressionCaseInsensitive
                               error:&error];
    if (!error) {
      result = [regex
          stringByReplacingMatchesInString:result
                                   options:0
                                     range:NSMakeRange(0, [result length])
                              withTemplate:@" "];
    }
    return [result
        stringByTrimmingCharactersInSet:[NSCharacterSet
                                            whitespaceAndNewlineCharacterSet]];
  }
}

// 郵便記号 '〒' を削除するヘルパーメソッド
// info の OCR 結果で郵便番号が含まれる場合に先頭や本文中の '〒' を取り除く
+ (NSString *)removePostalMarkFromText:(NSString *)text {
  if (!text || [text length] == 0) {
    return @"";
  }

  NSString *result = text;
  // 日本語の郵便記号 '〒' を削除
  result = [result stringByReplacingOccurrencesOfString:@"〒" withString:@""];
  // 念のため Unicode 表現も削除
  result = [result stringByReplacingOccurrencesOfString:@"\u3012"
                                             withString:@""];

  // 前後の空白を削除
  result = [result
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];

  return result;
}

// Info設問専用の表構造解析と文字認識メソッド（内部用）
// 使用StoredType: info
+ (NSString *)detectInfoAnswerRawFromImage:(UIImage *)image {
  // 統一前処理を適用
  NSString *errorCode = nil;
  cv::Mat gray = [self prepareImageForProcessing:image
                                       errorCode:&errorCode
                                      methodName:@"detectInfoAnswer"
                                     originalMat:NULL];

  if (errorCode) {
    return @"";
  }

  NSLog(@"OpenCVWrapper: detectInfoAnswer - 入力画像サイズ: %dx%d", gray.cols,
        gray.rows);

  // Step 1: 表の外側枠線を検出
  cv::Rect tableOuterBounds = [self detectTableOuterBounds:gray];

  if (tableOuterBounds.width <= 0 || tableOuterBounds.height <= 0) {
    NSLog(@"OpenCVWrapper: detectInfoAnswer - 表の外側枠線が見つかりません");
    return @"";
  }

  NSLog(
      @"OpenCVWrapper: detectInfoAnswer - 表の外側枠線: x=%d, y=%d, w=%d, h=%d",
      tableOuterBounds.x, tableOuterBounds.y, tableOuterBounds.width,
      tableOuterBounds.height);

  // Step 2: 表内領域を抽出
  cv::Mat tableROI = gray(tableOuterBounds);

  // Step 3: 列分割用の垂直線を検出（左列と右列を分離）
  int dividerX = [self detectColumnDivider:tableROI];

  if (dividerX <= 0) {
    NSLog(
        @"OpenCVWrapper: detectInfoAnswer - 列分割用の垂直線が見つかりません");
    return @"";
  }

  NSLog(@"OpenCVWrapper: detectInfoAnswer - 列分割位置: x=%d", dividerX);

  // Step 4: 右列（記述欄）を抽出
  int rightColumnX = dividerX + 5; // 垂直線から少し右にオフセット
  int rightColumnWidth = tableROI.cols - rightColumnX - 5; // 右端から少し内側

  if (rightColumnWidth <= 0) {
    NSLog(@"OpenCVWrapper: detectInfoAnswer - 右列の幅が無効です");
    return @"";
  }

  cv::Rect rightColumnRect(rightColumnX, 0, rightColumnWidth, tableROI.rows);
  cv::Mat rightColumnROI = tableROI(rightColumnRect);

  NSLog(@"OpenCVWrapper: detectInfoAnswer - 右列領域: x=%d, y=%d, w=%d, h=%d",
        rightColumnRect.x, rightColumnRect.y, rightColumnRect.width,
        rightColumnRect.height);

  // Step 5: 右列内の水平線を検出して行を分割
  std::vector<int> horizontalLines =
      [self detectHorizontalLinesInColumn:rightColumnROI];

  if (horizontalLines.size() < 2) {
    NSLog(@"OpenCVWrapper: detectInfoAnswer - 十分な水平線が見つかりません");
    return @"";
  }

  NSLog(@"OpenCVWrapper: detectInfoAnswer - 検出された水平線数: %zu",
        horizontalLines.size());

  // Step 6: 各行から文字を抽出
  NSMutableArray<NSString *> *rowTexts = [NSMutableArray array];

  for (size_t i = 0; i < horizontalLines.size() - 1; i++) {
    int topY = horizontalLines[i] + 2;        // 水平線から少し下
    int bottomY = horizontalLines[i + 1] - 2; // 次の水平線まで少し上
    int rowHeight = bottomY - topY;

    if (rowHeight <= 10) { // 高さが小さすぎる場合はスキップ
      NSLog(
          @"OpenCVWrapper: detectInfoAnswer - 行%zu: 高さが小さすぎます (h=%d)",
          i, rowHeight);
      continue;
    }

    cv::Rect rowRect(0, topY, rightColumnROI.cols, rowHeight);
    cv::Mat rowROI = rightColumnROI(rowRect);

    // 統一されたOCR前処理を適用（cv::Matオーバーロードを使用）
    cv::Mat processedRowROI =
        [OpenCVWrapper prepareImageForOCRProcessingFromMat:rowROI];
    NSLog(@"OpenCVWrapper: detectInfoAnswer - 行%zu: y=%d, h=%d "
          @"(OCR前処理適用済み)",
          i, topY, rowHeight);

    // 前処理済みの行のROIをUIImageに変換してVisionで文字認識
    UIImage *rowImage = MatToUIImage(processedRowROI);
    NSString *recognizedText = [self recognizeTextFromImage:rowImage];

    if (recognizedText && [recognizedText length] > 0) {
      // スペースと改行を除去して1行化
      NSString *cleanedText = [self normalizeOCRText:recognizedText
                                        removeSpaces:YES];
      // 郵便記号 '〒' を削除して正規化
      NSString *noPostal = [self removePostalMarkFromText:cleanedText];
      [rowTexts addObject:noPostal];
      NSLog(@"OpenCVWrapper: detectInfoAnswer - 行%zu認識テキスト: '%@' -> "
            @"郵便記号除去後: '%@'",
            i, cleanedText, noPostal);
    } else {
      [rowTexts addObject:@""];
      NSLog(@"OpenCVWrapper: detectInfoAnswer - 行%zu: "
            @"テキストが認識されませんでした",
            i);
    }
  }

  // 結果を結合して返す（各行を改行で区切り）
  NSString *result = [rowTexts componentsJoinedByString:@"\n"];
  NSLog(@"OpenCVWrapper: detectInfoAnswer - 最終結果: '%@'", result);

  return result;
}

// optionTexts を考慮したラッパー
// optionArray は行ごとの InfoField.rawValue の配列 (例: @[["name"],["zip"],
// ...]) を想定
+ (NSString *)detectInfoAnswerFromImage:(UIImage *)image
                        withOptionArray:(NSArray<NSString *> *)optionArray {
  if (image == nil) {
    return @"";
  }

  // 既存のテーブル/行分割 OCR
  // 実装を呼び出して、行ごとのテキストを改行で受け取る
  NSString *rawResult = [self detectInfoAnswerRawFromImage:image];
  if (!rawResult || [rawResult length] == 0) {
    return @"";
  }

  NSArray<NSString *> *lines = [rawResult componentsSeparatedByString:@"\n"];
  NSMutableArray<NSString *> *outLines =
      [NSMutableArray arrayWithCapacity:[lines count]];

  for (NSUInteger i = 0; i < [lines count]; i++) {
    NSString *line = lines[i];
    NSString *trimmed = [line
        stringByTrimmingCharactersInSet:[NSCharacterSet
                                            whitespaceAndNewlineCharacterSet]];

    // 対応する option が存在し、かつそれが "zip" の場合は郵便記号を除去する
    NSString *opt = nil;
    if (optionArray && i < [optionArray count]) {
      opt = optionArray[i];
    }

    if (opt && [opt isKindOfClass:[NSString class]] &&
        [opt isEqualToString:@"zip"]) {
      NSString *noPostal = [self removePostalMarkFromText:trimmed];
      [outLines addObject:noPostal ?: @""];
    } else {
      [outLines addObject:trimmed ?: @""];
    }
  }

  NSString *final = [outLines componentsJoinedByString:@"\n"];
  return final;
}

// 列分割用の垂直線を検出するヘルパーメソッド
// 使用StoredType: info
+ (int)detectColumnDivider:(cv::Mat)tableROI {
  int dividerX = -1;

  try {
    // 改善点:
    // - 投影値は画素強度の総和に相当するため、255で割って白ピクセル数に変換する
    // - 複数のスケール(minLineHeight) を試して縦線が見つかるか確認する
    // - 投影閾値は絶対値ではなく割合に基づく柔軟な閾値を使う
    // - 最後のフォールバックとして Sobel と HoughLinesP を試行する

    // 二値化は共通ラッパを使用して adaptive -> Otsu の流れを統一
    cv::Mat binary = [self adaptiveOrOtsuThreshold:tableROI blockSize:15 C:5];

    cv::Mat binaryInv;
    cv::bitwise_not(binary, binaryInv);

    int imgCols = tableROI.cols;
    int imgRows = tableROI.rows;

    // 試すスケール(表の高さに対する縦線の最小長さ比)
    std::vector<double> scales = {0.6, 0.4, 0.25, 0.15};
    int bestCount = 0;
    int bestX = -1;

    for (double scale : scales) {
      int minLineHeight = std::max(3, (int)std::round(imgRows * scale));
      cv::Mat kernel =
          cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, minLineHeight));

      cv::Mat verticalLines;
      cv::morphologyEx(binaryInv, verticalLines, cv::MORPH_OPEN, kernel);

      // 投影（列ごとの白ピクセル数）を得る
      cv::Mat projection = [self projectionSum:verticalLines axis:0];

      int startX = imgCols * 0.05;
      int endX = imgCols * 0.95;
      int maxCount = 0;
      int maxX = -1;

      for (int x = startX; x < endX; x++) {
        int sumVal = projection.at<int>(0, x);
        // 255で割ることで "白ピクセル数" に変換
        int whitePixels = sumVal / 255;
        if (whitePixels > maxCount) {
          maxCount = whitePixels;
          maxX = x;
        }
      }

      double ratio = (double)maxCount / (double)imgRows; // 0.0 - 1.0
      NSLog(@"OpenCVWrapper: detectColumnDivider(scale=%.2f) - maxWhite=%d, "
            @"ratio=%.3f, x=%d",
            scale, maxCount, ratio, maxX);

      // 柔軟閾値: 列の高さの15%程度の連続白ピクセルがあれば採用
      if (maxCount > bestCount && ratio >= 0.08) {
        bestCount = maxCount;
        bestX = maxX;
      }

      // 早期打ち切り: 明確な縦線が見つかったら終了
      if (ratio >= 0.25) {
        dividerX = maxX;
        break;
      }
    }

    if (dividerX == -1 && bestX >= 0) {
      dividerX = bestX;
    }

    // Sobel を使ったフォールバック（縦方向の勾配を利用）
    if (dividerX == -1) {
      cv::Mat sobelX;
      cv::Sobel(tableROI, sobelX, CV_16S, 1, 0, 3);
      cv::Mat absSobel;
      cv::convertScaleAbs(sobelX, absSobel);
      cv::Mat thr;
      cv::threshold(absSobel, thr, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
      cv::Mat proj = [self projectionSum:thr axis:0];
      int maxCount = 0;
      int maxX = -1;
      for (int x = imgCols * 0.05; x < imgCols * 0.95; x++) {
        int cnt = proj.at<int>(0, x) / 255;
        if (cnt > maxCount) {
          maxCount = cnt;
          maxX = x;
        }
      }
      double ratio = (double)maxCount / (double)imgRows;
      NSLog(@"OpenCVWrapper: detectColumnDivider(sobel) - maxWhite=%d, "
            @"ratio=%.3f, x=%d",
            maxCount, ratio, maxX);
      if (maxX >= 0 && ratio >= 0.06) {
        dividerX = maxX;
      }
    }

    // HoughLinesP をフォールバックとして使用（エッジから直線を検出）
    if (dividerX == -1) {
      cv::Mat edges;
      cv::Canny(tableROI, edges, 50, 150);
      std::vector<cv::Vec4i> linesP;
      // minLineLength を表の高さの 40% 程度に設定
      int minLineLen = std::max(10, (int)std::round(imgRows * 0.4));
      cv::HoughLinesP(edges, linesP, 1, CV_PI / 180, 50, minLineLen, 10);

      std::vector<int> xCandidates;
      for (auto &l : linesP) {
        int x1 = l[0], y1 = l[1], x2 = l[2], y2 = l[3];
        double angle = atan2((double)(y2 - y1), (double)(x2 - x1));
        double deg = fabs(angle * 180.0 / CV_PI);
        // 垂直に近い線（90度に近い）を採用
        if (deg > 80 && deg < 100) {
          int xc = (x1 + x2) / 2;
          if (xc > imgCols * 0.05 && xc < imgCols * 0.95)
            xCandidates.push_back(xc);
        }
      }

      if (!xCandidates.empty()) {
        // 中央値を取る
        std::sort(xCandidates.begin(), xCandidates.end());
        int mid = xCandidates[xCandidates.size() / 2];
        dividerX = mid;
        NSLog(@"OpenCVWrapper: detectColumnDivider(hough) - candidates=%zu, "
              @"selected=%d",
              xCandidates.size(), dividerX);
      } else {
        NSLog(@"OpenCVWrapper: detectColumnDivider - Hough "
              @"でも垂直線が見つかりませんでした");
      }
    }

    if (dividerX > 0) {
      NSLog(@"OpenCVWrapper: detectColumnDivider - 最終検出位置: x=%d",
            dividerX);
    } else {
      NSLog(@"OpenCVWrapper: detectColumnDivider - 検出に失敗しました "
            @"(dividerX=%d)",
            dividerX);
    }

  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: detectColumnDivider でエラー: %s", e.what());
  }

  return dividerX;
}

// 右列内の水平線を検出するヘルパーメソッド
// 使用StoredType: info
+ (std::vector<int>)detectHorizontalLinesInColumn:(cv::Mat)columnROI {
  std::vector<int> lines;

  try {
    // 二値化
    cv::Mat binary = [self adaptiveOrOtsuThreshold:columnROI blockSize:15 C:5];

    // 水平線検出のためのカーネル
    int minLineWidth = columnROI.cols * 0.3; // 列の幅の30%以上
    cv::Mat kernel =
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(minLineWidth, 1));

    cv::Mat binaryInv;
    cv::bitwise_not(binary, binaryInv);

    cv::Mat horizontalLines;
    cv::morphologyEx(binaryInv, horizontalLines, cv::MORPH_OPEN, kernel);

    // 水平線の投影を計算
    cv::Mat projection = [self projectionSum:horizontalLines axis:1];

    // 投影値が閾値以上の位置を検出
    int threshold = columnROI.cols * 0.2; // 列幅の20%以上 を維持
    for (int y = 0; y < projection.rows; y++) {
      int val = projection.at<int>(y, 0);
      if (val > threshold)
        lines.push_back(y);
    }

    // 近接する線をマージ（mergeCloseLines ヘルパを使用、10ピクセル）
    std::vector<int> mergedLines = [self mergeCloseLines:lines gap:10];

    NSLog(@"OpenCVWrapper: detectHorizontalLinesInColumn - 検出された水平線数: "
          @"%zu -> %zu (マージ後)",
          lines.size(), mergedLines.size());

    for (size_t i = 0; i < mergedLines.size(); i++) {
      NSLog(@"  水平線%zu: y=%d", i, mergedLines[i]);
    }

    return mergedLines;

  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: detectHorizontalLinesInColumn でエラー: %s",
          e.what());
  }

  return lines;
}

@end
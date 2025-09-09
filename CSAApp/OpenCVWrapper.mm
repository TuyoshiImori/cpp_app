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

+ (NSDictionary *)processImageWithCircleDetectionAndCrop:(UIImage *)image {
  // 入力画像のnilチェック
  if (image == nil) {
    NSLog(@"OpenCVWrapper: 入力画像がnilです");
    return @{
      @"processedImage" : image ?: [NSNull null],
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // UIImage -> cv::Mat
  cv::Mat mat;
  UIImageToMat(image, mat);

  // 入力画像が空の場合
  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: 入力画像が空です");
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  NSLog(@"OpenCVWrapper: 元画像 channels=%d, type=%d, size=%dx%d",
        mat.channels(), mat.type(), mat.cols, mat.rows);

  // === 画像処理部分 ===
  // 1. 画像を拡大（処理の精度向上のため）
  cv::Mat resizedMat;
  try {
    cv::resize(mat, resizedMat, cv::Size(), 2.0, 2.0, cv::INTER_LINEAR);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: resizeでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 2. グレースケール変換（拡大した画像から）
  cv::Mat grayMat;
  try {
    if (resizedMat.channels() == 4) {
      cv::cvtColor(resizedMat, grayMat, cv::COLOR_RGBA2GRAY);
    } else if (resizedMat.channels() == 3) {
      cv::cvtColor(resizedMat, grayMat, cv::COLOR_BGR2GRAY);
    } else if (resizedMat.channels() == 1) {
      grayMat = resizedMat.clone();
    } else {
      NSLog(@"OpenCVWrapper: 未対応のチャンネル数: %d", resizedMat.channels());
      return @{
        @"processedImage" : image,
        @"circleCenters" : @[],
        @"croppedImages" : @[]
      };
    }
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: グレースケール変換でエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 3. ガウシアンブラーで平滑化
  cv::Mat blurMat;
  try {
    cv::GaussianBlur(grayMat, blurMat, cv::Size(3, 3), 1.0);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: GaussianBlurでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 4. 適応的二値化
  cv::Mat binaryMat;
  // 適応的二値化のパラメータを調整
  try {
    cv::adaptiveThreshold(blurMat, binaryMat, 255,
                          cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY,
                          25, // ブロックサイズを19から25に変更
                          5); // 定数を2から5に変更
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: adaptiveThresholdでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 白黒反転前にさらに平滑化処理を追加
  cv::Mat extraBlurMat;
  try {
    cv::GaussianBlur(binaryMat, extraBlurMat, cv::Size(5, 5),
                     2.0); // カーネルサイズを5x5に変更し、標準偏差を2.0に設定
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: extra GaussianBlurでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 5. 白黒反転
  cv::Mat invMat;
  try {
    cv::bitwise_not(extraBlurMat, invMat); // extraBlurMatを使用
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: bitwise_notでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 6. ノイズ除去（モルフォロジーオープン）
  cv::Mat noNoiseMat;
  // モルフォロジーオープンのカーネルサイズを拡大
  try {
    cv::Mat kernel = cv::getStructuringElement(
        cv::MORPH_RECT, cv::Size(3, 3)); // カーネルサイズを2x2から3x3に変更
    cv::morphologyEx(invMat, noNoiseMat, cv::MORPH_OPEN, kernel);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: morphologyExでエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 7. 再度反転
  cv::Mat finalMat;
  try {
    cv::bitwise_not(noNoiseMat, finalMat);
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: bitwise_not(2)でエラー: %s", e.what());
    return @{
      @"processedImage" : image,
      @"circleCenters" : @[],
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

  // === 円検出部分 ===
  // 元画像のグレースケール版を作成（円検出用）
  cv::Mat originalGrayMat;
  try {
    if (mat.channels() == 4) {
      cv::cvtColor(mat, originalGrayMat, cv::COLOR_RGBA2GRAY);
    } else if (mat.channels() == 3) {
      cv::cvtColor(mat, originalGrayMat, cv::COLOR_BGR2GRAY);
    } else if (mat.channels() == 1) {
      originalGrayMat = mat.clone();
    }
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: 元画像グレースケール変換でエラー: %s", e.what());
    return @{
      @"processedImage" : processedImage ?: image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 軽いガウシアンブラーでノイズ除去
  cv::Mat blurredOriginalMat;
  cv::GaussianBlur(originalGrayMat, blurredOriginalMat, cv::Size(3, 3), 1.0);

  // テンプレートマッチングによるマーカー検出 (q.png をテンプレートとして使用)
  std::vector<cv::Vec3f> circles; // (x, y, r) の配列として扱う
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
        @"circleCenters" : @[],
        @"croppedImages" : @[]
      };
    }

    cv::Mat tplMat;
    UIImageToMat(tplUIImage, tplMat);
    if (tplMat.empty()) {
      NSLog(@"OpenCVWrapper: テンプレート画像が空です");
      return @{
        @"processedImage" : [NSNull null],
        @"circleCenters" : @[],
        @"croppedImages" : @[]
      };
    }

    // テンプレートもグレースケール化しておく
    cv::Mat tplGray;
    if (tplMat.channels() == 4)
      cv::cvtColor(tplMat, tplGray, cv::COLOR_RGBA2GRAY);
    else if (tplMat.channels() == 3)
      cv::cvtColor(tplMat, tplGray, cv::COLOR_BGR2GRAY);
    else
      tplGray = tplMat.clone();

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

      // テンプレートの中心を円の中心とみなす
      float centerX = static_cast<float>(maxLoc.x) + tplGray.cols / 2.0f;
      float centerY = static_cast<float>(maxLoc.y) + tplGray.rows / 2.0f;
      float radius = std::max(tplGray.cols, tplGray.rows) / 2.0f;
      circles.push_back(cv::Vec3f(centerX, centerY, radius));

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
          circles.size());
  } catch (const cv::Exception &e) {
    NSLog(@"OpenCVWrapper: テンプレートマッチングでエラー: %s", e.what());
    return @{
      @"processedImage" : processedImage ?: image,
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // テンプレート検出結果がなければ終了
  if (circles.empty()) {
    NSLog(@"OpenCVWrapper: テンプレートマッチで何も検出されませんでした");
    return @{
      @"processedImage" : [NSNull null],
      @"circleCenters" : @[],
      @"croppedImages" : @[]
    };
  }

  // 検出された中心点を NSArray に変換
  NSMutableArray<NSValue *> *circleCenters = [NSMutableArray array];
  for (const auto &circle : circles) {
    CGPoint center = CGPointMake(circle[0], circle[1]);
    [circleCenters addObject:[NSValue valueWithCGPoint:center]];
  }

  // === 画像切り取り部分 ===
  NSMutableArray<UIImage *> *croppedImages = [NSMutableArray array];

  if (!circles.empty()) {
    // 円をy座標でソート（上から下へ）
    std::sort(
        circles.begin(), circles.end(),
        [](const cv::Vec3f &a, const cv::Vec3f &b) { return a[1] < b[1]; });

    NSLog(@"OpenCVWrapper: 切り取り領域計算開始");
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
        const auto &nextCircle = circles[i + 1];
        int nextCircleTop = static_cast<int>(nextCircle[1] - nextCircle[2]);
        height = nextCircleTop - startY;
      } else {
        height = mat.rows - startY;
      }

      // 縦幅が0以下の場合はスキップ
      if (height <= 0) {
        NSLog(@"OpenCVWrapper: 円%zu: 高さが不正 (%d)", i, height);
        continue;
      }

      // 画像の範囲内に調整
      height = std::min(height, mat.rows - startY);

      NSLog(@"OpenCVWrapper: 円%zu: 切り取り領域 x=%d, y=%d, w=%d, h=%d", i,
            startX, startY, width, height);

      try {
        cv::Rect cropRect(startX, startY, width, height);
        cv::Mat croppedMat = mat(cropRect);
        UIImage *croppedImage = MatToUIImage(croppedMat);
        if (croppedImage != nil) {
          [croppedImages addObject:croppedImage];
        }
      } catch (const cv::Exception &e) {
        NSLog(@"OpenCVWrapper: 円%zu: 切り取りでエラー: %s", i, e.what());
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
    @"circleCenters" : circleCenters,
    @"croppedImages" : croppedImages
  };
}

// 切り取った設問画像ごとにStoredTypeとoptionTextsを受け取り、種類ごとに処理を振り分ける
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

  NSMutableArray<NSString *> *parsedAnswers = [NSMutableArray array];

  for (size_t i = 0; i < n; ++i) {
    NSString *storedType = (types && i < [types count]) ? types[i] : @"unknown";
    NSArray<NSString *> *optionArray =
        (optionTexts && i < [optionTexts count]) ? optionTexts[i] : @[];
    NSInteger optCount = [optionArray count];

    // 各要素ごとに storedType と対応する optionCount を明示的に出力
    // optionTexts の内容を個別に出力して文字化けを回避
    NSLog(@"OpenCVWrapper: index=%zu -> storedType=%@, optionCount=%ld", i,
          storedType, (long)optCount);
    for (NSUInteger j = 0; j < [optionArray count]; j++) {
      NSString *option = optionArray[j];
      NSLog(@"  option[%lu]: %@", (unsigned long)j, option);
    }

    // StoredType ごとの分岐（今はログ出力のみ）。後で OpenCV
    // ロジックをここに入れる。
    if ([storedType isEqualToString:@"single"]) {
      NSLog(@"OpenCVWrapper: index=%zu -> handling as SINGLE with %ld options",
            i, (long)optCount);
      // TODO: OpenCV で single チェックをここで実行
      [parsedAnswers addObject:@"-1"]; // ダミー: 未選択
    } else if ([storedType isEqualToString:@"multiple"]) {
      NSLog(
          @"OpenCVWrapper: index=%zu -> handling as MULTIPLE with %ld options",
          i, (long)optCount);
      // TODO: OpenCV で multiple チェックをここで実行
      [parsedAnswers addObject:@"-1"]; // ダミー
    } else if ([storedType isEqualToString:@"text"]) {
      NSLog(@"OpenCVWrapper: index=%zu -> handling as TEXT", i);
      [parsedAnswers addObject:@"0"]; // テキストは選択肢なし
    } else if ([storedType isEqualToString:@"info"]) {
      NSLog(@"OpenCVWrapper: index=%zu -> handling as INFO", i);
      [parsedAnswers addObject:@"0"]; // 情報フィールドは選択肢なし
    } else {
      NSLog(@"OpenCVWrapper: index=%zu -> handling as UNKNOWN", i);
      [parsedAnswers addObject:@"0"];
    }
  }

  return @{
    @"processedImage" : image ?: [NSNull null],
    @"parsedAnswers" : parsedAnswers
  };
}

@end

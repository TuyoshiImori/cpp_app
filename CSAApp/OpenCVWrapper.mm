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

    // StoredType ごとの分岐：実際のOpenCV処理を実装
    if ([storedType isEqualToString:@"single"]) {
      NSLog(@"OpenCVWrapper: index=%zu -> handling as SINGLE with %ld options",
            i, (long)optCount);

      // チェックボックス検出処理を実行
      UIImage *croppedImage = croppedImages[i];
      NSString *result = [self detectSingleAnswerFromImage:croppedImage
                                               withOptions:optionArray];
      [parsedAnswers addObject:result];
    } else if ([storedType isEqualToString:@"multiple"]) {
      NSLog(
          @"OpenCVWrapper: index=%zu -> handling as MULTIPLE with %ld options",
          i, (long)optCount);

      // 複数回答チェックボックス検出処理を実行
      UIImage *croppedImage = croppedImages[i];
      NSString *result = [self detectMultipleAnswerFromImage:croppedImage
                                                 withOptions:optionArray];
      [parsedAnswers addObject:result];
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

// チェックボックス検出のヘルパーメソッド
+ (NSString *)detectSingleAnswerFromImage:(UIImage *)image
                              withOptions:(NSArray<NSString *> *)options {
  if (image == nil || [options count] == 0) {
    NSLog(@"OpenCVWrapper: detectSingleAnswer - 無効な入力");
    return @"-1";
  }

  // UIImage -> cv::Mat
  cv::Mat mat;
  UIImageToMat(image, mat);

  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: detectSingleAnswer - 空の画像");
    return @"-1";
  }

  // グレースケール変換
  cv::Mat gray;
  if (mat.channels() == 4) {
    cv::cvtColor(mat, gray, cv::COLOR_RGBA2GRAY);
  } else if (mat.channels() == 3) {
    cv::cvtColor(mat, gray, cv::COLOR_BGR2GRAY);
  } else {
    gray = mat.clone();
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
+ (NSString *)detectMultipleAnswerFromImage:(UIImage *)image
                                withOptions:(NSArray<NSString *> *)options {
  if (image == nil || [options count] == 0) {
    NSLog(@"OpenCVWrapper: detectMultipleAnswer - 無効な入力");
    return @"-1";
  }

  // UIImage -> cv::Mat
  cv::Mat mat;
  UIImageToMat(image, mat);

  if (mat.empty()) {
    NSLog(@"OpenCVWrapper: detectMultipleAnswer - 空の画像");
    return @"-1";
  }

  // グレースケール変換
  cv::Mat gray;
  if (mat.channels() == 4) {
    cv::cvtColor(mat, gray, cv::COLOR_RGBA2GRAY);
  } else if (mat.channels() == 3) {
    cv::cvtColor(mat, gray, cv::COLOR_BGR2GRAY);
  } else {
    gray = mat.clone();
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

  // チェックされた選択肢の中に「その他」があるかチェック
  NSString *otherText = nil;
  for (NSString *checkedOption in checkedOptions) {
    BOOL isOtherOption = ([checkedOption containsString:@"その他"] ||
                          [checkedOption containsString:@"そのた"] ||
                          [checkedOption containsString:@"other"] ||
                          [checkedOption containsString:@"Other"]);

    if (isOtherOption) {
      NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
            @"チェックされた選択肢に「その他」が含まれています: %@",
            checkedOption);
      NSString *freeText = [self detectOtherFreeText:gray
                                          checkboxes:checkboxes];
      if (freeText && ![freeText isEqualToString:@""]) {
        otherText = freeText;
        NSLog(
            @"OpenCVWrapper: detectMultipleAnswer - その他の自由回答を検出: %@",
            otherText);
      }
      break;
    }
  }

  // チェックが見つからない場合は「その他」の可能性をチェック
  if ([checkedOptions count] == 0) {
    NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
          @"チェックが見つからないため、その他を確認");

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
        NSLog(@"OpenCVWrapper: detectMultipleAnswer - 「その他」選択肢を発見: "
              @"index=%d, option=%@",
              i, option);
        break;
      }
    }

    if (hasOtherOption && otherOptionIndex >= 0 &&
        otherOptionIndex < checkboxes.size()) {
      // 「その他」の選択肢があり、対応するチェックボックスが存在するため、自由回答を検出
      NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
            @"「その他」の自由回答を検出試行中（チェックなし）");

      NSString *freeText = [self detectOtherFreeTextAtIndex:gray
                                                 checkboxes:checkboxes
                                                      index:otherOptionIndex];

      if (freeText && ![freeText isEqualToString:@""]) {
        NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
              @"チェックなしでその他の自由回答を検出: %@",
              freeText);
        return freeText;
      } else {
        NSLog(@"OpenCVWrapper: detectMultipleAnswer - "
              @"「その他」の自由回答が見つからない");
      }
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
  NSString *finalResult = [results componentsJoinedByString:@","];
  NSLog(@"OpenCVWrapper: detectMultipleAnswer - 最終結果: %@", finalResult);
  return finalResult;
}

// チェックボックス矩形検出
+ (std::vector<cv::Rect>)detectCheckboxes:(cv::Mat)gray {
  std::vector<cv::Rect> checkboxes;

  try {
    // https://stackoverflow.com/questions/63084676/checkbox-detection-opencv
    // 上の方法を参考に実装
    // Step 1: 二値化
    cv::Mat binary;
    cv::threshold(gray, binary, 180, 255, cv::THRESH_OTSU);

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
+ (BOOL)isCheckboxChecked:(cv::Mat)gray rect:(cv::Rect)rect {
  try {
    // チェックボックス領域を抽出
    cv::Mat roi = gray(rect);

    // 二値化
    cv::Mat binary;
    cv::threshold(roi, binary, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);

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

    NSLog(@"OpenCVWrapper: detectOtherFreeText - テキスト領域: x=%d, y=%d, "
          @"w=%d, h=%d",
          textRect.x, textRect.y, textRect.width, textRect.height);

    // ROIをUIImageに変換してVisionで文字認識
    UIImage *textImage = MatToUIImage(textROI);

    // Vision APIを使用して文字認識
    NSString *recognizedText = [self recognizeTextFromImage:textImage];

    if (recognizedText) {
      // 括弧を除去する処理
      NSString *cleanedText = [self removeParenthesesFromText:recognizedText];
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

    NSLog(@"OpenCVWrapper: detectOtherFreeTextAtIndex - テキスト領域: x=%d, "
          @"y=%d, "
          @"w=%d, h=%d",
          textRect.x, textRect.y, textRect.width, textRect.height);

    // ROIをUIImageに変換してVisionで文字認識
    UIImage *textImage = MatToUIImage(textROI);

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

  // 日本語の括弧（）と英語の括弧()の両方に対応
  NSError *error = nil;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"[（(]([^）)]*)[）)]"
                           options:NSRegularExpressionCaseInsensitive
                             error:&error];
  if (error) {
    NSLog(@"OpenCVWrapper: extractTextFromParentheses - 正規表現エラー: %@",
          error.localizedDescription);
    return @"";
  }

  NSArray<NSTextCheckingResult *> *matches =
      [regex matchesInString:text
                     options:0
                       range:NSMakeRange(0, [text length])];

  if (matches.count > 0) {
    // 最初の括弧内の文字列を取得
    NSTextCheckingResult *match = matches[0];
    if (match.numberOfRanges >= 2) {
      NSRange captureRange =
          [match rangeAtIndex:1]; // キャプチャグループ1（括弧内の文字）
      NSString *extractedText = [text substringWithRange:captureRange];

      // 前後の空白を削除
      return
          [extractedText stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
  }

  // 括弧が見つからない場合は空文字を返す（「その他」の文字のみの場合など）
  NSLog(@"OpenCVWrapper: extractTextFromParentheses - "
        @"括弧内の文字が見つかりません: '%@'",
        text);
  return @"";
}

// Vision APIを使用した文字認識
+ (NSString *)recognizeTextFromImage:(UIImage *)image {
  if (!image) {
    NSLog(@"OpenCVWrapper: recognizeTextFromImage - 画像がnilです");
    return @"";
  }

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

@end

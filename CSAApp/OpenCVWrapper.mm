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

// 画像からマーカー(円)を検出し、設問ごとに切り取りを行う（旧:
// processImageWithCircleDetectionAndCrop:）
+ (NSDictionary *)detectCirclesAndCrop:(UIImage *)image {
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
        NSLog(@"OpenCVWrapper: Q%zu: 高さが不正 (%d)", i, height);
        continue;
      }

      // 画像の範囲内に調整
      height = std::min(height, mat.rows - startY);

      NSLog(@"OpenCVWrapper: Q%zu: 切り取り領域 x=%d, y=%d, w=%d, h=%d", i,
            startX, startY, width, height);

      try {
        cv::Rect cropRect(startX, startY, width, height);
        cv::Mat croppedMat = mat(cropRect);
        UIImage *croppedImage = MatToUIImage(croppedMat);
        if (croppedImage != nil) {
          [croppedImages addObject:croppedImage];
        }
      } catch (const cv::Exception &e) {
        NSLog(@"OpenCVWrapper: Q%zu: 切り取りでエラー: %s", i, e.what());
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

// 新 API 実装: StoredType の文字列配列を受け取り、OpenCV
// 側でタイプごとの分岐ログを出力する
// 画像を切り取り、その後 StoredType に基づいて解析を行う
+ (NSDictionary *)detectAndParseWithStoredTypes:(UIImage *)image
                                withStoredTypes:(NSArray<NSString *> *)types {
  NSDictionary *baseResult = [self detectCirclesAndCrop:image];

  if (!types || types.count == 0) {
    NSLog(@"OpenCVWrapper: StoredTypes が渡されていません。通常処理のみ実行。");
    return baseResult;
  }

  NSArray *cropped = baseResult[@"croppedImages"];
  if (!cropped || cropped.count == 0) {
    NSLog(@"OpenCVWrapper: "
          @"切り取り画像がありません。StoredTypeごとの解析をスキップします。");
    return baseResult;
  }

  // StoredTypes から設問ごとの選択肢数配列を作成してログ出力する
  NSMutableArray<NSNumber *> *optionCounts =
      [NSMutableArray arrayWithCapacity:types.count];
  for (NSString *st in types) {
    NSArray<NSString *> *parts = [st componentsSeparatedByString:@":"];
    if (parts.count > 1) {
      int v = [parts[1] intValue];
      if (v <= 0)
        v = -1; // 無効な値は -1 として扱う
      [optionCounts addObject:@(v)];
    } else {
      if ([st hasPrefix:@"single"] || [st hasPrefix:@"multiple"]) {
        // single/multiple だが数が指定されていない場合は -1
        [optionCounts addObject:@(-1)];
      } else {
        // text/info は 0
        [optionCounts addObject:@(0)];
      }
    }
  }
  NSLog(@"OpenCVWrapper: optionCounts = %@", optionCounts);

  // 解析結果を格納する配列
  NSMutableArray<NSString *> *parsedAnswers = [NSMutableArray array];

  // 各 StoredType に沿って切り取り画像を順に処理（まずはログ出力）
  NSUInteger count = MIN(types.count, cropped.count);
  for (NSUInteger i = 0; i < count; i++) {
    NSString *t = types[i];
    NSLog(@"OpenCVWrapper: StoredType[%lu] = %@ を処理開始 (画像 index=%lu)",
          (unsigned long)i, t, (unsigned long)i);

    // 簡易的な分岐ログ（将来的に各タイプごとの OpenCV 実装を呼ぶ）
    // 期待される選択肢数を type 文字列で渡せる（例: "single:4"）
    if ([t hasPrefix:@"single"]) {
      NSLog(@"OpenCVWrapper: single question -> 単一選択検出を開始します "
            @"(index=%lu)",
            (unsigned long)i);

      // 切り取り画像を取得
      UIImage *ci = nil;
      if (i < cropped.count) {
        ci = cropped[i];
      }
      if (!ci) {
        NSLog(@"OpenCVWrapper: single: 切り取り画像が無いためスキップ "
               "(index=%lu)",
              (unsigned long)i);
        // 画像が無い場合は検出数0を返す
        [parsedAnswers addObject:@"0"];
      } else {
        // UIImage -> cv::Mat
        cv::Mat qim;
        UIImageToMat(ci, qim);
        if (qim.empty()) {
          NSLog(@"OpenCVWrapper: single: cv::Mat 変換に失敗 (index=%lu)",
                (unsigned long)i);
          // 変換失敗時は検出数0を返す
          [parsedAnswers addObject:@"0"];
        } else {
          // 前処理: グレースケール、適応閾値
          cv::Mat g;
          if (qim.channels() == 3)
            cv::cvtColor(qim, g, cv::COLOR_BGR2GRAY);
          else if (qim.channels() == 4)
            cv::cvtColor(qim, g, cv::COLOR_RGBA2GRAY);
          else
            g = qim.clone();

          cv::Mat b;
          cv::GaussianBlur(g, b, cv::Size(3, 3), 1.0);
          cv::Mat th;
          cv::adaptiveThreshold(b, th, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                                cv::THRESH_BINARY_INV, 25, 5);

          // 輪郭検出
          std::vector<std::vector<cv::Point>> contours;
          cv::findContours(th, contours, cv::RETR_EXTERNAL,
                           cv::CHAIN_APPROX_SIMPLE);

          // チェックボックス候補の矩形を抽出（正方形寄りに限定）
          std::vector<cv::Rect> boxes;
          for (const auto &cnt : contours) {
            cv::Rect r = cv::boundingRect(cnt);
            // 面積と比率でフィルタ (経験的閾値)
            int area = r.width * r.height;
            if (area < 100 || area > (qim.cols * qim.rows / 4))
              continue;
            double ar = (double)r.width / (double)r.height;
            // 正方形に近いものだけ残す（幅/高さがほぼ等しい）
            if (ar < 0.7 || ar > 1.43)
              continue; // 正方形から大きく外れるものを除外
            // 正方形に正規化（中心を維持して辺長を max(width,height) にする）
            int side = std::max(r.width, r.height);
            int cx = r.x + r.width / 2;
            int cy = r.y + r.height / 2;
            int nx = cx - side / 2;
            int ny = cy - side / 2;
            // 画像範囲内に制限
            nx = std::max(0, nx);
            ny = std::max(0, ny);
            if (nx + side > qim.cols)
              side = qim.cols - nx;
            if (ny + side > qim.rows)
              side = qim.rows - ny;
            boxes.push_back(cv::Rect(nx, ny, side, side));
          }

          // boxes が空なら検出数0を返す
          if (boxes.empty()) {
            NSLog(@"OpenCVWrapper: single: "
                  @"チェックボックス候補が見つかりませんでした (index=%lu)",
                  (unsigned long)i);
            [parsedAnswers addObject:@"0"];
          } else {
            // 検出された矩形の数をログ出力
            NSLog(@"OpenCVWrapper: single: 初期検出矩形数=%zu (index=%lu)",
                  boxes.size(), (unsigned long)i);
            // 重複を簡易除去: 中心でソートして近接マージ
            std::sort(boxes.begin(), boxes.end(),
                      [](const cv::Rect &a, const cv::Rect &b) {
                        if (std::abs(a.y - b.y) >
                            std::max(a.height, b.height) / 2)
                          return a.y < b.y;
                        return a.x < b.x;
                      });

            // 近接ボックスのマージ/重複除去
            std::vector<cv::Rect> merged;
            for (const auto &r : boxes) {
              bool mergedFlag = false;
              for (auto &mr : merged) {
                cv::Rect inter = mr & r;
                double interArea = (double)inter.area();
                double smaller = (double)std::min(mr.area(), r.area());
                if (interArea / smaller > 0.4) { // 40% 重複で同一視
                  mr = mr | r;                   // union
                  mergedFlag = true;
                  break;
                }
              }
              if (!mergedFlag)
                merged.push_back(r);
            }

            // ソート: 上→下、左→右
            std::sort(merged.begin(), merged.end(),
                      [](const cv::Rect &a, const cv::Rect &b) {
                        if (std::abs(a.y - b.y) >
                            std::max(a.height, b.height) / 2)
                          return a.y < b.y;
                        return a.x < b.x;
                      });

            // マージ後の矩形数をログ出力
            NSLog(@"OpenCVWrapper: single: マージ後矩形数=%zu (index=%lu)",
                  merged.size(), (unsigned long)i);

            // 呼び出し元が "single:4"
            // のように期待選択数を渡している場合、それを解析する
            int expectedChoices = -1;
            NSArray<NSString *> *parts = [t componentsSeparatedByString:@":"];
            if (parts.count > 1) {
              expectedChoices = [parts[1] intValue];
              if (expectedChoices <= 0)
                expectedChoices = -1;
            }

            // デフォルトでは merged を選択候補とする
            std::vector<cv::Rect> selectedBoxes = merged; // default

            // expectedChoices
            // が設定され、候補が多い場合はスライディングウィンドウで選択
            if (expectedChoices > 0 && (int)merged.size() > expectedChoices) {
              // 辺長を収集
              std::vector<int> sides;
              for (const auto &r : merged)
                sides.push_back(std::max(r.width, r.height));

              std::vector<int> sidesCopy = sides;
              std::sort(sidesCopy.begin(), sidesCopy.end());
              double medianSide = sidesCopy[sidesCopy.size() / 2];

              size_t M = merged.size();
              double bestScore = 1e300;
              size_t bestStart = 0;
              for (size_t s = 0; s + (size_t)expectedChoices <= M; ++s) {
                double score = 0.0;
                for (size_t k = 0; k < (size_t)expectedChoices; ++k) {
                  score += std::abs((double)sides[s + k] - medianSide);
                }
                int xstart = merged[s].x;
                int xend = merged[s + expectedChoices - 1].x +
                           merged[s + expectedChoices - 1].width;
                double span = (double)(xend - xstart);
                double finalScore = score + span * 0.5;
                if (finalScore < bestScore) {
                  bestScore = finalScore;
                  bestStart = s;
                }
              }
              selectedBoxes.clear();
              for (size_t k = 0; k < (size_t)expectedChoices; ++k) {
                selectedBoxes.push_back(merged[bestStart + k]);
              }
              // 空間的にソート
              std::sort(selectedBoxes.begin(), selectedBoxes.end(),
                        [](const cv::Rect &a, const cv::Rect &b) {
                          if (std::abs(a.y - b.y) >
                              std::max(a.height, b.height) / 2)
                            return a.y < b.y;
                          return a.x < b.x;
                        });
              // スライディングウィンドウで期待数に絞れなかった場合のフォールバック
              if ((int)selectedBoxes.size() != expectedChoices) {
                // 辺長が中央値に近いものを選択して expectedChoices 個にする
                std::vector<std::pair<double, size_t>> diffs;
                for (size_t idx = 0; idx < merged.size(); ++idx) {
                  int s = std::max(merged[idx].width, merged[idx].height);
                  diffs.emplace_back(
                      std::make_pair(std::abs((double)s - medianSide), idx));
                }
                std::sort(diffs.begin(), diffs.end(),
                          [](const auto &a, const auto &b) {
                            return a.first < b.first;
                          });
                selectedBoxes.clear();
                for (int k = 0; k < expectedChoices && (size_t)k < diffs.size();
                     ++k) {
                  selectedBoxes.push_back(merged[diffs[k].second]);
                }
                std::sort(selectedBoxes.begin(), selectedBoxes.end(),
                          [](const cv::Rect &a, const cv::Rect &b) {
                            if (std::abs(a.y - b.y) >
                                std::max(a.height, b.height) / 2)
                              return a.y < b.y;
                            return a.x < b.x;
                          });
                NSLog(
                    @"OpenCVWrapper: single(overload): フォールバックで候補を "
                    @"expectedChoices=%d に調整しました (index=%lu)",
                    expectedChoices, (unsigned long)i);
              }
              // スライディングウィンドウで期待数に絞れなかった場合のフォールバック
              if ((int)selectedBoxes.size() != expectedChoices) {
                // 辺長が中央値に近いものを選択して expectedChoices 個にする
                std::vector<std::pair<double, size_t>> diffs;
                for (size_t idx = 0; idx < merged.size(); ++idx) {
                  int s = std::max(merged[idx].width, merged[idx].height);
                  diffs.emplace_back(
                      std::make_pair(std::abs((double)s - medianSide), idx));
                }
                std::sort(diffs.begin(), diffs.end(),
                          [](const auto &a, const auto &b) {
                            return a.first < b.first;
                          });
                selectedBoxes.clear();
                for (int k = 0; k < expectedChoices && (size_t)k < diffs.size();
                     ++k) {
                  selectedBoxes.push_back(merged[diffs[k].second]);
                }
                std::sort(selectedBoxes.begin(), selectedBoxes.end(),
                          [](const cv::Rect &a, const cv::Rect &b) {
                            if (std::abs(a.y - b.y) >
                                std::max(a.height, b.height) / 2)
                              return a.y < b.y;
                            return a.x < b.x;
                          });
                NSLog(@"OpenCVWrapper: single: フォールバックで候補を "
                      @"expectedChoices=%d に調整しました (index=%lu)",
                      expectedChoices, (unsigned long)i);
              }
            }

            // 絞り込み後の候補数をログ出力
            NSLog(@"OpenCVWrapper: single: 絞り込み後候補数=%zu (index=%lu)",
                  selectedBoxes.size(), (unsigned long)i);

            // connectedComponents
            // でマークを抽出し、重心を最も近いボックスに割り当てる
            cv::Mat labels, stats, centroids;
            int ncomp = cv::connectedComponentsWithStats(th, labels, stats,
                                                         centroids, 8, CV_32S);

            // 対象ボックスは selectedBoxes
            std::vector<cv::Rect> targetBoxes = selectedBoxes;
            NSLog(@"OpenCVWrapper: single: 最終割当対象数=%zu (index=%lu)",
                  targetBoxes.size(), (unsigned long)i);
            std::vector<bool> checked(targetBoxes.size(), false);
            std::vector<bool> compAssigned(std::max(0, ncomp), false);

            for (int ci = 1; ci < ncomp; ci++) {
              double cx = centroids.at<double>(ci, 0);
              double cy = centroids.at<double>(ci, 1);
              int bestIdx = -1;
              double bestDist = 1e12;
              for (size_t bi = 0; bi < targetBoxes.size(); bi++) {
                const cv::Rect &br = targetBoxes[bi];
                double bx = br.x + br.width / 2.0;
                double by = br.y + br.height / 2.0;
                if (cx >= br.x && cx < br.x + br.width && cy >= br.y &&
                    cy < br.y + br.height) {
                  double d = (cx - bx) * (cx - bx) + (cy - by) * (cy - by);
                  if (d < bestDist) {
                    bestDist = d;
                    bestIdx = (int)bi;
                  }
                  continue;
                }
                double dx = cx - bx;
                double dy = cy - by;
                double d = dx * dx + dy * dy;
                double thresh = (std::max(br.width, br.height) / 2.0) * 1.5;
                if (d <= thresh * thresh) {
                  if (d < bestDist) {
                    bestDist = d;
                    bestIdx = (int)bi;
                  }
                }
              }
              if (bestIdx >= 0 && !compAssigned[ci]) {
                checked[bestIdx] = true;
                compAssigned[ci] = true;
              }
            }

            // single の場合は「チェックがついている選択肢のインデックス」を返す
            std::vector<int> checkedIndices;
            for (size_t bi = 0; bi < checked.size(); ++bi) {
              if (checked[bi])
                checkedIndices.push_back((int)bi);
            }
            NSString *detectedAnswer = nil;
            if (checkedIndices.size() == 1) {
              detectedAnswer =
                  [NSString stringWithFormat:@"%d", checkedIndices[0]];
            } else {
              // チェックが見つからなかった場合
              // 期待選択数(expectedChoices) が与えられていればその数を返す
              if (expectedChoices > 0) {
                detectedAnswer =
                    [NSString stringWithFormat:@"%d", expectedChoices];
              } else {
                // targetBoxes の中で辺長が中央値に近いものを数える
                int sameSizeCount = 0;
                std::vector<int> sidesForCount;
                for (const auto &r : targetBoxes) {
                  sidesForCount.push_back(std::max(r.width, r.height));
                }
                if (!sidesForCount.empty()) {
                  std::vector<int> tmp = sidesForCount;
                  std::sort(tmp.begin(), tmp.end());
                  double medianSide = tmp[tmp.size() / 2];
                  if (medianSide <= 0) {
                    sameSizeCount = (int)sidesForCount.size();
                  } else {
                    for (int s : sidesForCount) {
                      double rel =
                          std::abs((double)s - medianSide) / medianSide;
                      if (rel <= 0.25) // 25% 以内を同サイズとみなす
                        sameSizeCount++;
                    }
                  }
                } else {
                  sameSizeCount = (int)merged.size();
                }
                detectedAnswer =
                    [NSString stringWithFormat:@"%d", sameSizeCount];
              }
            }
            NSLog(@"OpenCVWrapper: single: 検出インデックス=%@ (index=%lu)",
                  detectedAnswer, (unsigned long)i);
            [parsedAnswers addObject:detectedAnswer];
          }
        }
      }
    } else if ([t isEqualToString:@"multiple"]) {
      NSLog(@"OpenCVWrapper: multiple question -> "
            @"ここで複数選択の検出ロジックを呼び出します (index=%lu)",
            (unsigned long)i);
      // 仮の値として "1" を返す
      [parsedAnswers addObject:@"1"];
    } else if ([t isEqualToString:@"text"]) {
      NSLog(@"OpenCVWrapper: text question -> "
            @"ここでテキスト回答の検出ロジックを呼び出します (index=%lu)",
            (unsigned long)i);
      [parsedAnswers addObject:@"1"];
    } else if ([t isEqualToString:@"info"]) {
      NSLog(@"OpenCVWrapper: info question -> "
            @"ここで個人情報フィールド抽出ロジックを呼び出します (index=%lu)",
            (unsigned long)i);
      [parsedAnswers addObject:@"1"];
    } else {
      NSLog(
          @"OpenCVWrapper: 未知の StoredType=%@ (index=%lu)。スキップします。",
          t, (unsigned long)i);
      [parsedAnswers addObject:@"1"];
    }
  }

  // 戻り値に parsedAnswers を追加して返す
  NSMutableDictionary *ret = [baseResult mutableCopy];
  ret[@"parsedAnswers"] = parsedAnswers;
  return ret;
}

// 新 API 実装: 既に切り取った画像リストを受け取り、StoredTypeごとの解析を行う
// StoredImages を受け取り、StoredType ごとの解析を行う（旧:
// processImageWithCircleDetectionAndCrop:withCroppedImages:withStoredTypes:）
+ (NSDictionary *)parseCroppedImages:(UIImage *)image
                   withCroppedImages:(NSArray<UIImage *> *)croppedImages
                     withStoredTypes:(NSArray<NSString *> *)types {
  // もし croppedImages が nil または空なら、元の処理で切り取りを行ってもらう
  NSDictionary *baseResult = nil;
  if (!croppedImages || croppedImages.count == 0) {
    baseResult = [self detectCirclesAndCrop:image];
    croppedImages = baseResult[@"croppedImages"];
  } else {
    // 既に切り取り画像がある場合は processedImage と circleCenters は生成しない
    // 最小限の戻り値を作る
    baseResult = @{
      @"processedImage" : image ?: [NSNull null],
      @"circleCenters" : @[],
      @"croppedImages" : croppedImages
    };
  }

  if (!types || types.count == 0) {
    NSLog(@"OpenCVWrapper: StoredTypes が渡されていません。通常処理のみ実行。");
    return baseResult;
  }

  if (!croppedImages || croppedImages.count == 0) {
    NSLog(@"OpenCVWrapper: "
          @"切り取り画像がありません。StoredTypeごとの解析をスキップします。");
    return baseResult;
  }

  // 解析結果を格納する配列
  NSMutableArray<NSString *> *parsedAnswers = [NSMutableArray array];

  // 既存の解析ループを再利用するために、types と croppedImages を使って処理
  NSUInteger count = MIN(types.count, croppedImages.count);
  for (NSUInteger i = 0; i < count; i++) {
    NSString *t = types[i];
    UIImage *ci = croppedImages[i];
    // ログは既存実装に合わせる
    NSLog(@"OpenCVWrapper: StoredType[%lu] = %@ を処理開始 (画像 index=%lu)",
          (unsigned long)i, t, (unsigned long)i);

    // 以下は既存の detectAndParseWithStoredTypes: の処理内容と同等
    // の中の 各タイプ分岐と検出ロジックと同等の処理をインラインで呼び出す。
    if ([t hasPrefix:@"single"]) {
      if (!ci) {
        [parsedAnswers addObject:@"0"];
        continue;
      }
      cv::Mat qim;
      UIImageToMat(ci, qim);
      if (qim.empty()) {
        [parsedAnswers addObject:@"0"];
        continue;
      }

      cv::Mat g;
      if (qim.channels() == 3)
        cv::cvtColor(qim, g, cv::COLOR_BGR2GRAY);
      else if (qim.channels() == 4)
        cv::cvtColor(qim, g, cv::COLOR_RGBA2GRAY);
      else
        g = qim.clone();

      cv::Mat b;
      cv::GaussianBlur(g, b, cv::Size(3, 3), 1.0);
      cv::Mat th;
      cv::adaptiveThreshold(b, th, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                            cv::THRESH_BINARY_INV, 25, 5);

      std::vector<std::vector<cv::Point>> contours;
      cv::findContours(th, contours, cv::RETR_EXTERNAL,
                       cv::CHAIN_APPROX_SIMPLE);

      std::vector<cv::Rect> boxes;
      for (const auto &cnt : contours) {
        cv::Rect r = cv::boundingRect(cnt);
        int area = r.width * r.height;
        if (area < 100 || area > (qim.cols * qim.rows / 4))
          continue;
        double ar = (double)r.width / (double)r.height;
        if (ar < 0.7 || ar > 1.43)
          continue;
        int side = std::max(r.width, r.height);
        int cx = r.x + r.width / 2;
        int cy = r.y + r.height / 2;
        int nx = cx - side / 2;
        int ny = cy - side / 2;
        nx = std::max(0, nx);
        ny = std::max(0, ny);
        if (nx + side > qim.cols)
          side = qim.cols - nx;
        if (ny + side > qim.rows)
          side = qim.rows - ny;
        boxes.push_back(cv::Rect(nx, ny, side, side));
      }

      if (boxes.empty()) {
        [parsedAnswers addObject:@"0"];
        continue;
      }

      // 初期検出矩形数をログ出力
      NSLog(@"OpenCVWrapper: single (overload): 初期検出矩形数=%zu (index=%lu)",
            boxes.size(), (unsigned long)i);

      std::sort(boxes.begin(), boxes.end(),
                [](const cv::Rect &a, const cv::Rect &b) {
                  if (std::abs(a.y - b.y) > std::max(a.height, b.height) / 2)
                    return a.y < b.y;
                  return a.x < b.x;
                });

      std::vector<cv::Rect> merged;
      for (const auto &r : boxes) {
        bool mergedFlag = false;
        for (auto &mr : merged) {
          cv::Rect inter = mr & r;
          double interArea = (double)inter.area();
          double smaller = (double)std::min(mr.area(), r.area());
          if (interArea / smaller > 0.4) {
            mr = mr | r;
            mergedFlag = true;
            break;
          }
        }
        if (!mergedFlag)
          merged.push_back(r);
      }

      std::sort(merged.begin(), merged.end(),
                [](const cv::Rect &a, const cv::Rect &b) {
                  if (std::abs(a.y - b.y) > std::max(a.height, b.height) / 2)
                    return a.y < b.y;
                  return a.x < b.x;
                });

      // マージ後の矩形数をログ出力
      NSLog(@"OpenCVWrapper: single (overload): マージ後矩形数=%zu (index=%lu)",
            merged.size(), (unsigned long)i);

      int expectedChoices = -1;
      NSArray<NSString *> *parts = [t componentsSeparatedByString:@":"];
      if (parts.count > 1) {
        expectedChoices = [parts[1] intValue];
        if (expectedChoices <= 0)
          expectedChoices = -1;
      }

      std::vector<cv::Rect> selectedBoxes = merged;
      if (expectedChoices > 0 && (int)merged.size() > expectedChoices) {
        std::vector<int> sides;
        for (const auto &r : merged)
          sides.push_back(std::max(r.width, r.height));
        std::vector<int> sidesCopy = sides;
        std::sort(sidesCopy.begin(), sidesCopy.end());
        double medianSide = sidesCopy[sidesCopy.size() / 2];
        size_t M = merged.size();
        double bestScore = 1e300;
        size_t bestStart = 0;
        for (size_t s = 0; s + (size_t)expectedChoices <= M; ++s) {
          double score = 0.0;
          for (size_t k = 0; k < (size_t)expectedChoices; ++k) {
            score += std::abs((double)sides[s + k] - medianSide);
          }
          int xstart = merged[s].x;
          int xend = merged[s + expectedChoices - 1].x +
                     merged[s + expectedChoices - 1].width;
          double span = (double)(xend - xstart);
          double finalScore = score + span * 0.5;
          if (finalScore < bestScore) {
            bestScore = finalScore;
            bestStart = s;
          }
        }
        selectedBoxes.clear();
        for (size_t k = 0; k < (size_t)expectedChoices; ++k) {
          selectedBoxes.push_back(merged[bestStart + k]);
        }
        std::sort(selectedBoxes.begin(), selectedBoxes.end(),
                  [](const cv::Rect &a, const cv::Rect &b) {
                    if (std::abs(a.y - b.y) > std::max(a.height, b.height) / 2)
                      return a.y < b.y;
                    return a.x < b.x;
                  });
      }

      // 絞り込み後の候補数をログ出力
      NSLog(
          @"OpenCVWrapper: single (overload): 絞り込み後候補数=%zu (index=%lu)",
          selectedBoxes.size(), (unsigned long)i);

      cv::Mat labels, stats, centroids;
      int ncomp = cv::connectedComponentsWithStats(th, labels, stats, centroids,
                                                   8, CV_32S);

      std::vector<cv::Rect> targetBoxes = selectedBoxes;
      NSLog(@"OpenCVWrapper: single (overload): 最終割当対象数=%zu (index=%lu)",
            targetBoxes.size(), (unsigned long)i);
      std::vector<bool> checked(targetBoxes.size(), false);
      std::vector<bool> compAssigned(std::max(0, ncomp), false);

      for (int ci2 = 1; ci2 < ncomp; ci2++) {
        double cx = centroids.at<double>(ci2, 0);
        double cy = centroids.at<double>(ci2, 1);
        int bestIdx = -1;
        double bestDist = 1e12;
        for (size_t bi = 0; bi < targetBoxes.size(); bi++) {
          const cv::Rect &br = targetBoxes[bi];
          double bx = br.x + br.width / 2.0;
          double by = br.y + br.height / 2.0;
          if (cx >= br.x && cx < br.x + br.width && cy >= br.y &&
              cy < br.y + br.height) {
            double d = (cx - bx) * (cx - bx) + (cy - by) * (cy - by);
            if (d < bestDist) {
              bestDist = d;
              bestIdx = (int)bi;
            }
            continue;
          }
          double dx = cx - bx;
          double dy = cy - by;
          double d = dx * dx + dy * dy;
          double thresh = (std::max(br.width, br.height) / 2.0) * 1.5;
          if (d <= thresh * thresh) {
            if (d < bestDist) {
              bestDist = d;
              bestIdx = (int)bi;
            }
          }
        }
        if (bestIdx >= 0 && !compAssigned[ci2]) {
          checked[bestIdx] = true;
          compAssigned[ci2] = true;
        }
      }

      std::vector<int> checkedIndices;
      for (size_t bi = 0; bi < checked.size(); ++bi) {
        if (checked[bi])
          checkedIndices.push_back((int)bi);
      }
      NSString *detectedAnswer = nil;
      if (checkedIndices.size() == 1) {
        detectedAnswer = [NSString stringWithFormat:@"%d", checkedIndices[0]];
      } else {
        if (expectedChoices > 0) {
          detectedAnswer = [NSString stringWithFormat:@"%d", expectedChoices];
        } else {
          int sameSizeCount = 0;
          std::vector<int> sidesForCount;
          for (const auto &r : targetBoxes)
            sidesForCount.push_back(std::max(r.width, r.height));
          if (!sidesForCount.empty()) {
            std::vector<int> tmp = sidesForCount;
            std::sort(tmp.begin(), tmp.end());
            double medianSide = tmp[tmp.size() / 2];
            if (medianSide <= 0) {
              sameSizeCount = (int)sidesForCount.size();
            } else {
              for (int s : sidesForCount) {
                double rel = std::abs((double)s - medianSide) / medianSide;
                if (rel <= 0.25)
                  sameSizeCount++;
              }
            }
          } else {
            sameSizeCount = (int)merged.size();
          }
          detectedAnswer = [NSString stringWithFormat:@"%d", sameSizeCount];
        }
      }
      [parsedAnswers addObject:detectedAnswer ?: @"0"];
    } else if ([t isEqualToString:@"multiple"]) {
      [parsedAnswers addObject:@"1"];
    } else if ([t isEqualToString:@"text"]) {
      [parsedAnswers addObject:@"1"];
    } else if ([t isEqualToString:@"info"]) {
      [parsedAnswers addObject:@"1"];
    } else {
      [parsedAnswers addObject:@"1"];
    }
  }

  NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{
    @"processedImage" : image ?: [NSNull null],
    @"circleCenters" : @[],
    @"croppedImages" : croppedImages
  }];
  ret[@"parsedAnswers"] = parsedAnswers;
  return ret;
}

@end

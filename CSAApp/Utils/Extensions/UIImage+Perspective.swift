import UIKit
import Vision

extension UIImage {
  /// 画像を統合処理（リサイズ→グレースケール→鮮鋭化→二値化→モルフォロジー処理、円検出、画像切り取り）し、
  /// 処理済み画像、円の中心座標、切り取り画像を返す
  func processWithOpenCV() -> (UIImage, [CGPoint], [UIImage]) {
    guard let result = OpenCVWrapper.detectCirclesAndCrop(self) else {
      return (self, [], [self])
    }

    let processedImage = result["processedImage"] as? UIImage ?? self
    let circleCenters = (result["circleCenters"] as? [NSValue])?.map { $0.cgPointValue } ?? []
    let croppedImages = result["croppedImages"] as? [UIImage] ?? [self]

    return (processedImage, circleCenters, croppedImages)
  }

  /// StoredTypeの文字列配列を渡して OpenCV 側でタイプ別処理を実行する（まずはログ出力）
  func processWithOpenCV(storedTypes: [String]) -> (UIImage, [CGPoint], [UIImage]) {
    // 互換性のため既存の戻り値を返す（parsedAnswers は別メソッドで取得可能）
    let (pi, cc, ci, parsed) = processWithOpenCVAndParsedAnswers(storedTypes: storedTypes)
    _ = parsed
    return (pi, cc, ci)
  }

  /// StoredType を渡して OpenCV 実行し、parsedAnswers も含めて返す
  func processWithOpenCVAndParsedAnswers(storedTypes: [String]) -> (
    UIImage, [CGPoint], [UIImage], [String]
  ) {
    // まず既存処理で切り取り画像を取得してから、切り取った画像リストを OpenCV に渡して解析を行う
    // これにより Swift 側の設問リストと切り取り画像を明確に対応させられる
    // まずは切り取りだけ行うベース呼び出し
    guard let base = OpenCVWrapper.detectCirclesAndCrop(self) else {
      return (self, [], [self], [])
    }
    let baseCropped = base["croppedImages"] as? [UIImage] ?? [self]

    guard
      let result = OpenCVWrapper.parseCroppedImages(
        self, withCroppedImages: baseCropped, withStoredTypes: storedTypes)
    else {
      return (self, [], [self], [])
    }

    let processedImage = result["processedImage"] as? UIImage ?? self
    let circleCenters = (result["circleCenters"] as? [NSValue])?.map { $0.cgPointValue } ?? []
    let croppedImages = result["croppedImages"] as? [UIImage] ?? [self]
    let parsed = result["parsedAnswers"] as? [NSString] ?? []
    let parsedStrings: [String] = parsed.map { $0 as String }

    return (processedImage, circleCenters, croppedImages, parsedStrings)
  }

  /// 画像をリサイズ→グレースケール→鮮鋭化→二値化→モルフォロジー処理（OpenCVで実装）→文字認識し、
  /// グレースケール画像と認識された文字列を返す
  func recognizeTextWithVisionSync() -> (UIImage, [String]) {
    // OpenCVWrapper経由で統合処理を行い、処理済み画像を取得
    let (processedImage, _, _) = processWithOpenCV()

    // Vision用にCGImage化
    guard let cgimg = processedImage.cgImage else { return (self, []) }

    // --- 以降はVisionで文字認識 ---
    var recognizedTexts: [String] = []
    let semaphore = DispatchSemaphore(value: 0)
    let request = VNRecognizeTextRequest { request, error in
      defer { semaphore.signal() }
      guard error == nil else { return }
      guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
      for observation in observations {
        if let topCandidate = observation.topCandidates(1).first {
          recognizedTexts.append(topCandidate.string)
        }
      }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["ja-JP"]  // 日本語を指定
    let handler = VNImageRequestHandler(cgImage: cgimg, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        // 無視
      }
    }
    semaphore.wait()
    // グレースケール画像を返す
    return (processedImage, recognizedTexts)
  }

  /// 円の検出を行い、円の中心座標と前処理済み画像を返す
  func detectCirclesWithVisionSync() -> ([CGPoint], UIImage) {
    let (processedImage, circleCenters, _) = processWithOpenCV()
    return (circleCenters, processedImage)
  }

  /// 円の検出に基づいて画像を複数の領域に切り取る
  func cropImagesByCircles() -> [UIImage] {
    let (_, _, croppedImages) = processWithOpenCV()
    return croppedImages
  }
}

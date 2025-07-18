import UIKit
import Vision

extension UIImage {
  /// 画像を統合処理（リサイズ→グレースケール→鮮鋭化→二値化→モルフォロジー処理、円検出、画像切り取り）し、
  /// 処理済み画像、円の中心座標、切り取り画像を返す
  func processWithOpenCV() -> (UIImage, [CGPoint], [UIImage]) {
    guard let result = OpenCVWrapper.processImage(withCircleDetectionAndCrop: self) else {
      return (self, [], [self])
    }

    let processedImage = result["processedImage"] as? UIImage ?? self
    let circleCenters = (result["circleCenters"] as? [NSValue])?.map { $0.cgPointValue } ?? []
    let croppedImages = result["croppedImages"] as? [UIImage] ?? [self]

    return (processedImage, circleCenters, croppedImages)
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

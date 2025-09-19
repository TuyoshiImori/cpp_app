import UIKit
import Vision

extension UIImage {
  /// 画像を統合処理（リサイズ→グレースケール→鮮鋭化→二値化→モルフォロジー処理、テンプレートマッチング、画像切り取り）し、
  /// 処理済み画像、テンプレートマッチング検出点、切り取り画像を返す
  func processWithOpenCV() -> (UIImage, [CGPoint], [UIImage]) {
    guard let result = OpenCVWrapper.processImageWithTemplate(matchingAndCrop: self) else {
      return (self, [], [self])
    }

    let processedImage = result["processedImage"] as? UIImage ?? self
    let templateCenters = (result["templateCenters"] as? [NSValue])?.map { $0.cgPointValue } ?? []
    let croppedImages = result["croppedImages"] as? [UIImage] ?? [self]

    return (processedImage, templateCenters, croppedImages)
  }

  /// 画像をリサイズ→グレースケール→鮮鋭化→二値化→モルフォロジー処理（OpenCVで実装）→文字認識し、
  /// グレースケール画像、認識された文字列、及びテンプレートマッチングに基づく切り取り画像配列を返す
  func recognizeTextWithVisionSync() -> (UIImage, [String], [UIImage]) {
    // OpenCVWrapper経由で統合処理を行い、処理済み画像と切り取り画像を取得
    let (processedImage, _, croppedImages) = processWithOpenCV()

    // Vision用にCGImage化
    guard let cgimg = processedImage.cgImage else { return (self, [], [self]) }

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
    // グレースケール画像、認識テキスト、切り取り画像を返す
    return (processedImage, recognizedTexts, croppedImages)
  }
}

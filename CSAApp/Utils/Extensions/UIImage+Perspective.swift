import UIKit
import Vision

extension UIImage {
  /// 画像をリサイズ→グレースケール→鮮鋭化→二値化→モルフォロジー処理（OpenCVで実装）→文字認識し、
  /// グレースケール画像と認識された文字列を返す
  func recognizeTextWithVisionSync() -> (UIImage, [String]) {
    // OpenCVWrapper経由で前処理済み画像を取得
    guard let processedImage = OpenCVWrapper.processImage(self) else { return (self, []) }
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
}

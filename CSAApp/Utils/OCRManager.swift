import Foundation
import UIKit
import Vision

/// Swift 側の Vision ベースの OCR ラッパ。
/// Objective-C/Objective-C++ からは `[OCRManager recognizeText: image]` で呼び出せる。
@objc public class OCRManager: NSObject {
  /// 画像からテキストを同期的に抽出して返す。
  /// - Parameter image: 入力 UIImage
  /// - Returns: 認識したテキスト（失敗時は空文字）
  @objc public static func recognizeText(_ image: UIImage) -> String {
    // CGImage が取れない場合は空文字を返す
    guard let cgImage = image.cgImage else {
      NSLog("OCRManager: recognizeText - UIImage.CGImage が nil です")
      return ""
    }

    // completionHandler はイニシャライザで渡す必要があるため、ここで初期化する
    var recognizedText = ""
    let semaphore = DispatchSemaphore(value: 0)

    let request = VNRecognizeTextRequest(completionHandler: { request, error in
      if let error = error {
        NSLog("OCRManager: VNRecognizeTextRequest エラー: %@", error.localizedDescription)
        semaphore.signal()
        return
      }

      guard let results = request.results as? [VNRecognizedTextObservation] else {
        semaphore.signal()
        return
      }

      // 上位候補をつなげて結果を作る
      let parts = results.compactMap { obs -> String? in
        return obs.topCandidates(1).first?.string
      }
      recognizedText = parts.joined(separator: " ")
      semaphore.signal()
    })
    // 精度重視
    request.recognitionLevel = .accurate
    if #available(iOS 13.0, *) {
      // 日本語と英語を優先
      request.recognitionLanguages = ["ja-JP", "en-US"]
      request.usesLanguageCorrection = true
    }

    // ここまでで request/completionHandler を準備済み
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
      try handler.perform([request])
    } catch {
      NSLog("OCRManager: VNImageRequestHandler.perform エラー: %@", error.localizedDescription)
      semaphore.signal()
    }

    // 5秒まで待つ
    _ = semaphore.wait(timeout: .now() + 5.0)
    return recognizedText
  }
}

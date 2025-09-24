import Foundation
import UIKit
import Vision

/// Swift 側の Vision ベースの OCR ラッパ。
/// Objective-C/Objective-C++ からは `[OCRManager recognizeText: image]` で呼び出せる。
@objc public class OCRManager: NSObject {
  /// 既存の互換 API を残す（古い呼び出しから壊さないため）
  @objc public static func recognizeText(_ image: UIImage) -> String {
    return recognizeText(image, question: nil, storedType: nil, infoFields: nil)
  }

  /// 拡張 API（将来的に question/ storedType/ infoFields を渡せるようにする）
  /// ただし現在は LLM を使わず、Vision の生 OCR 結果を正規化して返す
  @objc public static func recognizeText(
    _ image: UIImage,
    question: String?,
    storedType: String?,
    infoFields: [String]?
  ) -> String {
    // CGImage が取れない場合は空文字を返す
    guard let cgImage = image.cgImage else {
      NSLog("OCRManager: recognizeText - UIImage.CGImage が nil です")
      return ""
    }

    var recognizedText = ""
    let semaphore = DispatchSemaphore(value: 0)

    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        NSLog("OCRManager: VNRecognizeTextRequest エラー: %@", error.localizedDescription)
        semaphore.signal()
        return
      }

      guard let results = request.results as? [VNRecognizedTextObservation] else {
        semaphore.signal()
        return
      }

      let parts = results.compactMap { obs -> String? in
        return obs.topCandidates(1).first?.string
      }
      recognizedText = parts.joined(separator: " ")
      semaphore.signal()
    }

    request.recognitionLevel = .accurate
    if #available(iOS 13.0, *) {
      request.recognitionLanguages = ["ja-JP", "en-US"]
      request.usesLanguageCorrection = true
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
      try handler.perform([request])
    } catch {
      NSLog("OCRManager: VNImageRequestHandler.perform エラー: %@", error.localizedDescription)
      semaphore.signal()
    }

    // 最大5秒待つ
    _ = semaphore.wait(timeout: .now() + 5.0)

    // OpenCV 側に渡す際は空白・改行を除去
    let forOpenCV = recognizedText.replacingOccurrences(
      of: "\\s+", with: "", options: .regularExpression)

    return forOpenCV
  }
}

import Foundation
import UIKit
import Vision

/// Swift 側の Vision ベースの OCR ラッパ。
/// Objective-C/Objective-C++ からは `[OCRManager recognizeText: image]` で呼び出せる。
@objc public class OCRManager: NSObject {
  /// 既存の互換 API を残す（古い呼び出しから壊さないため）
  @objc public static func recognizeText(_ image: UIImage) -> String {
    let result = recognizeText(image, question: nil, storedType: nil, infoFields: nil)
    return result["text"] as? String ?? ""
  }

  /// 拡張 API（将来的に question/ storedType/ infoFields を渡せるようにする）
  /// 信頼度も含む結果を辞書形式で返すように変更
  @objc public static func recognizeText(
    _ image: UIImage,
    question: String?,
    storedType: String?,
    infoFields: [String]?
  ) -> NSDictionary {
    // CGImage が取れない場合は空の辞書を返す
    guard let cgImage = image.cgImage else {
      NSLog("OCRManager: recognizeText - UIImage.CGImage が nil です")
      return ["text": "", "confidence": 0.0]
    }

    var recognizedText = ""
    var confidenceScore: Float = 0.0
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

      let partsWithConfidence = results.compactMap { obs -> (String, Float)? in
        guard let candidate = obs.topCandidates(1).first else { return nil }
        return (candidate.string, candidate.confidence)
      }

      // テキストを結合し、信頼度の平均を計算
      let parts = partsWithConfidence.map { $0.0 }
      recognizedText = parts.joined(separator: " ")

      if !partsWithConfidence.isEmpty {
        let totalConfidence = partsWithConfidence.map { $0.1 }.reduce(0, +)
        confidenceScore = totalConfidence / Float(partsWithConfidence.count)
      }

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

    // 信頼度をパーセンテージに変換（0-1の値を0-100にする）
    let confidencePercentage = confidenceScore * 100.0

    NSLog("OCRManager: recognizeText - 認識結果: '%@', 信頼度: %.1f%%", forOpenCV, confidencePercentage)

    return [
      "text": forOpenCV,
      "confidence": confidencePercentage,
    ]
  }
}

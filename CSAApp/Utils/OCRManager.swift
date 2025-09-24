import Foundation
import UIKit
import Vision

#if canImport(FoundationModels)
  import FoundationModels
#endif

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

    // OCR の生の結果
    let ocrText = recognizedText
    NSLog("OCRManager: OCR before LLM: '%@'", ocrText)

    var correctedText = ocrText

    // FoundationModels が利用可能であれば LLM に投げて校正を試みる
    #if canImport(FoundationModels)
      if #available(iOS 17.0, *) {
        // 非同期 API を同期的に待つためにセマフォを使う（短時間タイムアウト）
        let semaphore2 = DispatchSemaphore(value: 0)
        Task {
          do {
            let session = LanguageModelSession()
            let prompt = """
              以下はOCRで読み取った文字列です。OCR特有の誤認識を可能な限り修正して、正しい日本語の文字列で返してください。
              出力は校正後のテキストだけにしてください。
              入力: "\(ocrText)"
              """

            let response = try await session.respond(to: prompt)
            correctedText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
          } catch {
            NSLog("OCRManager: LLM 校正エラー: %@", String(describing: error))
          }
          semaphore2.signal()
        }

        // LLM の応答を最大で 5 秒待つ
        _ = semaphore2.wait(timeout: .now() + 5.0)
      }
    #else
      // FoundationModels がなければ何もしない（フォールバック）
    #endif

    NSLog("OCRManager: OCR after LLM: '%@'", correctedText)

    // OpenCV 側に渡す際は余分な空白や改行を取り除き、連続した文字列にする
    let forOpenCV = correctedText.replacingOccurrences(
      of: "\\s+", with: "", options: .regularExpression)
    NSLog("OCRManager: OCR for OpenCV: '%@'", forOpenCV)

    return forOpenCV
  }
}

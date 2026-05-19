import FoundationModels
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class DebugOCRViewModel: ObservableObject {
  @Published var selectedPhotoItem: PhotosPickerItem? = nil
  @Published var selectedImage: UIImage? = nil
  @Published var croppedImage: UIImage? = nil
  @Published var recognizedText: String = ""
  @Published var confidence: Float = 0.0
  @Published var isProcessing: Bool = false

  // AI補正用
  @Published var editableText: String = ""
  @Published var correctedText: String = ""
  @Published var isCorrecting: Bool = false
  @Published var aiError: String? = nil

  /// OCRにかける対象画像（クロップあり→クロップ画像、なし→元画像）
  var ocrTargetImage: UIImage? { croppedImage ?? selectedImage }

  func loadSelectedPhoto() async {
    guard let item = selectedPhotoItem,
      let data = try? await item.loadTransferable(type: Data.self),
      let image = UIImage(data: data)
    else { return }
    selectedImage = image
    resetResult()
  }

  func loadSampleImage() {
    guard let image = UIImage(named: "form") else { return }
    selectedImage = image
    resetResult()
  }

  func setCroppedImage(_ image: UIImage) {
    croppedImage = image
    resetOCRResult()
  }

  func clearCrop() {
    croppedImage = nil
    resetOCRResult()
  }

  func runOCR() async {
    guard let image = ocrTargetImage else { return }
    isProcessing = true
    defer { isProcessing = false }

    let result = await Task.detached(priority: .userInitiated) {
      OCRManager.recognizeText(image, question: nil, storedType: nil, infoFields: nil)
    }.value

    recognizedText = result["text"] as? String ?? ""
    confidence = result["confidence"] as? Float ?? 0.0
    editableText = recognizedText
    correctedText = ""
    aiError = nil
  }

  func correctWithAI() async {
    guard !editableText.isEmpty else { return }
    isCorrecting = true
    aiError = nil
    defer { isCorrecting = false }

    guard SystemLanguageModel.default.isAvailable else {
      aiError = "このデバイスはApple Intelligenceに対応していません"
      return
    }

    do {
      let session = LanguageModelSession(
        instructions: "あなたは演奏会で回収した手書きアンケートのOCR補正アシスタントです。与えられたテキストを補正した結果のみを返してください。説明や前置きは不要です。"
      )
      let prompt = """
        以下は演奏会で回収した手書きアンケートをOCRで読み取ったテキストです。演奏に関する感想が書かれていたことを考慮して誤認識されていると推測できる箇所を文脈から判断して補正し、正しい日本語テキストのみを返してください。

        OCRテキスト：\(editableText)
        """
      let response = try await session.respond(to: prompt)
      correctedText = response.content
    } catch {
      aiError = "AI補正に失敗しました: \(error.localizedDescription)"
    }
  }

  private func resetResult() {
    croppedImage = nil
    resetOCRResult()
  }

  private func resetOCRResult() {
    recognizedText = ""
    confidence = 0.0
    editableText = ""
    correctedText = ""
    aiError = nil
  }
}

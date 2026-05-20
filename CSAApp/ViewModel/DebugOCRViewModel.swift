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
      // 本番と同じ OpenCV 前処理（グレースケール・リサイズ・CLAHE・バイラテラルフィルタ・
      // シャープニング・適応的二値化・モルフォロジー処理）を適用してから OCR にかける
      let preprocessed = OpenCVWrapper.preprocessImage(forOCR: image) ?? image
      return OCRManager.recognizeText(preprocessed, question: nil, storedType: nil, infoFields: nil)
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
        instructions: """
          あなたは演奏会アンケートのOCR補正の専門家です。
          補正後のテキストのみを出力してください。説明・前置き・引用符は一切不要です。
          """
      )
      let prompt = """
        手書きアンケートをOCRで読み取ったテキストを補正してください。

        【OCRで起きやすい誤認識パターン】
        1. 字形が似た漢字の混同（例：音→青、手→千、日→目、人→入）
        2. カタカナの音が近い文字への変換（例：ヴァイオリン→ウェイオリン、チェロ→テエロ）
        3. ひらがなの部分一致による誤変換（例：ここちよく→ここうまく、すばらしい→すばやしい）

        【このアンケートに登場しやすい語彙】
        楽器：ヴァイオリン・チェロ・ビオラ・コントラバス・ピアノ・フルート・クラリネット・オーボエ・トランペット・ホルン・ハープ
        音楽用語：演奏・音色・旋律・ハーモニー・指揮・協奏曲・交響曲・作曲家・聴く・
        感想表現：心地よい・感動・素晴らしい・美しい・迫力・上手・素敵・楽しい・印象的・感銘・満足・よかった・面白い・興味深い
        強調表現：大変・非常に・とても・大いに・誠に・まことに・本当に・すごく・たいへん

        【誤認識の追加ヒント】
        - 助詞が不自然に連続する場合（例：「を〜を」「が〜が」）は直前の単語が誤認識されている可能性が高い
        - 文法的に意味をなさない単語が現れたら、前後の文脈から正しい語を推定する

        【補正例1】
        OCR：「ウェイオリンの青をここうまく聞かせていただきました」
        正解：「ヴァイオリンの音をここちよく聞かせていただきました」

        【補正例2】
        OCR：「初めてでしたが文を興味を持ちました」
        正解：「初めてでしたが大変興味を持ちました」
        ※「文を興味を持ちました」は助詞「を」が不自然に連続しており、「文を」→「大変」と補正

        上記の例のように、文法的な不自然さや文脈から正しい語を積極的に推定し、
        最も自然な演奏会の感想文になるよう補正してください。補正後のテキストのみ出力してください。

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

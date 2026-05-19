import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class DebugOCRViewModel: ObservableObject {
  @Published var selectedPhotoItem: PhotosPickerItem? = nil
  @Published var selectedImage: UIImage? = nil
  @Published var recognizedText: String = ""
  @Published var confidence: Float = 0.0
  @Published var isProcessing: Bool = false

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

  func runOCR() async {
    guard let image = selectedImage else { return }
    isProcessing = true
    defer { isProcessing = false }

    // OCRManagerをそのまま流用（本番と同じ実装）
    let result = await Task.detached(priority: .userInitiated) {
      OCRManager.recognizeText(image, question: nil, storedType: nil, infoFields: nil)
    }.value

    recognizedText = result["text"] as? String ?? ""
    confidence = result["confidence"] as? Float ?? 0.0
  }

  private func resetResult() {
    recognizedText = ""
    confidence = 0.0
  }
}

import AVFoundation
import Combine
import UIKit

final class CameraViewModel: NSObject, ObservableObject {
  @Published var capturedImage: UIImage?
  @Published var detectedFeature: RectangleFeature? = nil
  @Published var isTorchOn: Bool = false
  @Published var isTargetBracesVisible: Bool = true
  @Published var isAutoCaptureEnabled: Bool = true

  let scanner = AVDocumentScanner()

  override init() {
    super.init()
    scanner.setDelegate(self)
    scanner.start()
    isAutoCaptureEnabled = true
    scanner.isAutoCaptureEnabled = true
  }

  func toggleTorch() {
    scanner.toggleTorch()
    isTorchOn = scanner.lastTorchLevel > 0
  }

  func toggleTargetBraces() {
    isTargetBracesVisible.toggle()
  }

  func pauseAutoCapture() {
    isAutoCaptureEnabled = false
    scanner.isAutoCaptureEnabled = false
  }

  func resumeAutoCapture() {
    isAutoCaptureEnabled = true
    scanner.isAutoCaptureEnabled = true
    scanner.start()
  }

  func capturePhoto(completion: @escaping (UIImage?) -> Void) {
    scanner.captureImage(in: detectedFeature) { image in
      DispatchQueue.main.async {
        self.capturedImage = image
        self.pauseAutoCapture()
        completion(image)
      }
    }
  }
}

extension CameraViewModel: DocumentScannerDelegate {
  func didCapture(image: UIImage) {
    DispatchQueue.main.async {
      self.capturedImage = image
      self.pauseAutoCapture()
    }
  }

  func didRecognize(feature: RectangleFeature?, in image: CIImage) {
    DispatchQueue.main.async {
      self.detectedFeature = feature
    }
  }
}

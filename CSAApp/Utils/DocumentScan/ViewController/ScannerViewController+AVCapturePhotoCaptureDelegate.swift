import AVFoundation
import UIKit

extension ScannerViewController: AVCapturePhotoCaptureDelegate {
  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    if let error = error {
      print("Photo capture error: \(error)")
      return
    }
    guard let data = photo.fileDataRepresentation(),
      let image = UIImage(data: data)
    else { return }
    // ここでdelegate等に画像を渡す
    print("Photo captured")
  }
}

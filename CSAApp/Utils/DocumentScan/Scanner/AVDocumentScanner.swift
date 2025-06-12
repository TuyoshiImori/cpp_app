import AVFoundation
import UIKit

protocol AVDocumentScannerDelegate: AnyObject {
  func avDocumentScanner(_ scanner: AVDocumentScanner, didCapture image: UIImage)
  func avDocumentScanner(_ scanner: AVDocumentScanner, didFailWith error: Error)
}

final class AVDocumentScanner: NSObject {
  weak var delegate: AVDocumentScannerDelegate?

  private let captureSession = AVCaptureSession()
  private var videoOutput: AVCaptureVideoDataOutput?
  private var photoOutput: AVCapturePhotoOutput?
  private var previewLayer: AVCaptureVideoPreviewLayer?

  // プレビュー用レイヤーを取得
  func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
    if let layer = previewLayer {
      return layer
    }
    let layer = AVCaptureVideoPreviewLayer(session: captureSession)
    layer.videoGravity = .resizeAspectFill
    previewLayer = layer
    return layer
  }

  // セッション開始
  func startSession() {
    if !captureSession.isRunning {
      captureSession.startRunning()
    }
  }

  // セッション停止
  func stopSession() {
    if captureSession.isRunning {
      captureSession.stopRunning()
    }
  }

  // カメラセットアップ
  func configureCamera() {
    captureSession.beginConfiguration()
    defer { captureSession.commitConfiguration() }

    // 入力
    guard let device = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: device),
      captureSession.canAddInput(input)
    else { return }
    captureSession.addInput(input)

    // 静止画出力
    let photoOutput = AVCapturePhotoOutput()
    if captureSession.canAddOutput(photoOutput) {
      captureSession.addOutput(photoOutput)
      self.photoOutput = photoOutput
    }
  }

  // 写真撮影
  func capturePhoto() {
    let settings = AVCapturePhotoSettings()
    photoOutput?.capturePhoto(with: settings, delegate: self)
  }
}

extension AVDocumentScanner: AVCapturePhotoCaptureDelegate {
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    if let error = error {
      delegate?.avDocumentScanner(self, didFailWith: error)
      return
    }
    guard let data = photo.fileDataRepresentation(),
      let image = UIImage(data: data)
    else {
      delegate?.avDocumentScanner(
        self, didFailWith: NSError(domain: "AVDocumentScanner", code: -1, userInfo: nil))
      return
    }
    delegate?.avDocumentScanner(self, didCapture: image)
  }
}

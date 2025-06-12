import AVFoundation
import Combine
import UIKit

class CameraViewModel: NSObject, ObservableObject {
  let session = AVCaptureSession()
  private let photoOutput = AVCapturePhotoOutput()
  private let videoOutput = AVCaptureVideoDataOutput()
  private var device: AVCaptureDevice?
  private let documentScanner = DocumentScanner()
  private var cancellables = Set<AnyCancellable>()

  @Published var capturedImage: UIImage?
  @Published var detectedQuad: [CGPoint]? = nil
  @Published var isTorchOn: Bool = false
  @Published var isTargetBracesVisible: Bool = true
  @Published var isProcessingFrame: Bool = false

  // 追加: カメラ画像サイズ
  @Published var imageWidth: CGFloat = 1
  @Published var imageHeight: CGFloat = 1

  override init() {
    super.init()
    documentScanner.delegate = self
    setupSession()
  }

  private func setupSession() {
    session.beginConfiguration()
    guard let device = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input)
    else { return }
    self.device = device
    session.addInput(input)
    if session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)
    }
    if session.canAddOutput(videoOutput) {
      videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
      session.addOutput(videoOutput)
    }
    session.commitConfiguration()
  }

  func startSession() {
    if !session.isRunning {
      session.startRunning()
    }
  }

  func stopSession() {
    if session.isRunning {
      session.stopRunning()
    }
  }

  func capturePhoto() {
    let settings = AVCapturePhotoSettings()
    photoOutput.capturePhoto(with: settings, delegate: self)
  }

  func toggleTorch() {
    guard let device = device, device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      device.torchMode = device.torchMode == .on ? .off : .on
      device.unlockForConfiguration()
      isTorchOn = device.torchMode == .on
    } catch {}
  }

  func toggleTargetBraces() {
    isTargetBracesVisible.toggle()
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard !isProcessingFrame else { return }
    isProcessingFrame = true
    processFrame(sampleBuffer)
  }

  private func processFrame(_ sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      isProcessingFrame = false
      return
    }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
      isProcessingFrame = false
      return
    }
    // 画像サイズを保存
    DispatchQueue.main.async {
      self.imageWidth = CGFloat(cgImage.width)
      self.imageHeight = CGFloat(cgImage.height)
    }
    documentScanner.detectRectangle(in: cgImage)
  }
}

// MARK: - DocumentScannerDelegate
extension CameraViewModel: DocumentScannerDelegate {
  func documentScanner(_ scanner: DocumentScanner, didDetectRectangle feature: RectangleFeature) {
    DispatchQueue.main.async {
      print("Detected quad:", feature)
      self.detectedQuad = [
        feature.topLeft,
        feature.topRight,
        feature.bottomRight,
        feature.bottomLeft,
      ]
      self.isProcessingFrame = false
    }
  }
  func documentScanner(_ scanner: DocumentScanner, didFailWithError error: Error) {
    DispatchQueue.main.async {
      self.detectedQuad = nil
      self.isProcessingFrame = false
    }
  }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    if let error = error {
      print("Photo capture error: \(error)")
      return
    }
    guard let data = photo.fileDataRepresentation(),
      let image = UIImage(data: data)
    else { return }
    DispatchQueue.main.async {
      self.capturedImage = image
    }
  }
}

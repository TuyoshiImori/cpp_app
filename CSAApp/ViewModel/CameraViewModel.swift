import AVFoundation
import SwiftUI
import Vision

public class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  public let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let queue = DispatchQueue(label: "camera.frame.queue")
  public var onPhotoCapture: ((UIImage) -> Void)?
  @Published public var displayQuad: [CGPoint]? = nil
  private var lastDetectionTime: Date = Date()
  private let overlayHoldDuration: TimeInterval = 0.2  // 200ms保持
  private var isAutoMode: Bool = false
  private var autoCaptureCooldown: Bool = false
  private var recentFeatures: [RectangleFeature] = []
  private let smoothingFrameCount: Int = 5
  private let jitterThreshold: CGFloat = 10.0
  private var lastStableQuad: [CGPoint]? = nil

  public override init() {
    super.init()
    configure()
  }

  private func configure() {
    session.beginConfiguration()
    guard
      let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input),
      session.canAddOutput(output),
      session.canAddOutput(videoOutput)
    else {
      session.commitConfiguration()
      return
    }
    session.addInput(input)
    session.addOutput(output)
    session.addOutput(videoOutput)
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    videoOutput.setSampleBufferDelegate(self, queue: queue)
    session.commitConfiguration()
  }

  public func startSession(isAuto: Bool) {
    isAutoMode = isAuto
    autoCaptureCooldown = false
    recentFeatures.removeAll()
    if !session.isRunning {
      DispatchQueue.global(qos: .userInitiated).async {
        self.session.startRunning()
      }
    }
  }

  public func stopSession() {
    if session.isRunning {
      session.stopRunning()
    }
  }

  public func capturePhoto() {
    let settings = AVCapturePhotoSettings()
    output.capturePhoto(with: settings, delegate: self)
  }

  // 手動撮影時
  public func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    guard let data = photo.fileDataRepresentation(),
      let uiImage = UIImage(data: data)
    else { return }
    detectDocument(in: uiImage)
  }

  // リアルタイム矩形検出（自動モード時のみ）
  public func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard isAutoMode, !autoCaptureCooldown,
      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }

    let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

    let request = VNDetectRectanglesRequest { [weak self] req, _ in
      guard let self = self else { return }
      if let result = (req.results as? [VNRectangleObservation])?.max(by: {
        $0.confidence < $1.confidence
      }),
        result.confidence > 0.9
      {
        let feature = RectangleFeature.from(observation: result, width: width, height: height)
        self.recentFeatures.append(feature)
        if self.recentFeatures.count > self.smoothingFrameCount {
          self.recentFeatures.removeFirst()
        }

        // 外れ値除去: 中央値フィルタ
        let medianFeature = medianRectangleFeature(self.recentFeatures)
        let avgFeature = RectangleFeature.average(self.recentFeatures + [medianFeature])
        let jitter = RectangleFeature.jitter(self.recentFeatures)

        let quad = [
          CGPoint(x: avgFeature.topLeft.x / width, y: avgFeature.topLeft.y / height),
          CGPoint(x: avgFeature.topRight.x / width, y: avgFeature.topRight.y / height),
          CGPoint(x: avgFeature.bottomRight.x / width, y: avgFeature.bottomRight.y / height),
          CGPoint(x: avgFeature.bottomLeft.x / width, y: avgFeature.bottomLeft.y / height),
        ]
        DispatchQueue.main.async {
          self.displayQuad = quad
          self.lastStableQuad = quad
          self.lastDetectionTime = Date()
        }

        if self.recentFeatures.count == self.smoothingFrameCount && jitter < self.jitterThreshold {
          self.autoCaptureCooldown = true
          self.capturePhoto()
          self.recentFeatures.removeAll()
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.autoCaptureCooldown = false
          }
        }
      } else {
        // 検出できなかった場合は直前の値を一定時間保持
        DispatchQueue.main.async {
          if let last = self.lastStableQuad,
            Date().timeIntervalSince(self.lastDetectionTime) < self.overlayHoldDuration
          {
            self.displayQuad = last
          } else {
            self.displayQuad = nil
          }
        }
        self.recentFeatures.removeAll()
      }
    }
    request.minimumConfidence = 0.9
    request.minimumAspectRatio = 0.5
    request.maximumAspectRatio = 1.0
    request.quadratureTolerance = 20

    let handler = VNImageRequestHandler(
      cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
    try? handler.perform([request])
  }

  private func detectDocument(in image: UIImage) {
    guard let cgImage = image.cgImage else {
      DispatchQueue.main.async { self.onPhotoCapture?(image) }
      return
    }
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let request = VNDetectRectanglesRequest { [weak self] req, _ in
      guard let self = self else { return }
      if let result = req.results?.first as? VNRectangleObservation {
        let cropped = self.perspectiveCrop(image: image, rect: result)
        DispatchQueue.main.async { self.onPhotoCapture?(cropped ?? image) }
      } else {
        DispatchQueue.main.async { self.onPhotoCapture?(image) }
      }
    }
    request.minimumConfidence = 0.5
    request.minimumAspectRatio = 0.2
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try? handler.perform([request])
  }

  private func perspectiveCrop(image: UIImage, rect: VNRectangleObservation) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let ciImage = CIImage(cgImage: cgImage)
    let topLeft = CGPoint(x: rect.topLeft.x * width, y: (1 - rect.topLeft.y) * height)
    let topRight = CGPoint(x: rect.topRight.x * width, y: (1 - rect.topRight.y) * height)
    let bottomLeft = CGPoint(x: rect.bottomLeft.x * width, y: (1 - rect.bottomLeft.y) * height)
    let bottomRight = CGPoint(x: rect.bottomRight.x * width, y: (1 - rect.bottomRight.y) * height)

    guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
    filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
    filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
    filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")

    let context = CIContext()
    if let output = filter.outputImage,
      let cgOutput = context.createCGImage(output, from: output.extent)
    {
      return UIImage(cgImage: cgOutput)
    }
    return nil
  }
}

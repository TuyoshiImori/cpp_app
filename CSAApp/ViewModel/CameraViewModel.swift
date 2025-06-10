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
    let request = VNDetectRectanglesRequest { [weak self] req, _ in
      guard let self = self else { return }
      if let result = req.results?.first as? VNRectangleObservation {
        let cropped = self.perspectiveCrop(image: image, rect: result)
        DispatchQueue.main.async {
          self.onPhotoCapture?(cropped ?? image)
        }
      } else {
        DispatchQueue.main.async { self.onPhotoCapture?(image) }
      }
    }
    request.minimumConfidence = 0.5
    request.minimumAspectRatio = 0.2
    let orientation = CGImagePropertyOrientation(image.imageOrientation)
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
    try? handler.perform([request])
  }

  private func perspectiveCrop(image: UIImage, rect: VNRectangleObservation) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    let srcWidth = CGFloat(cgImage.width)
    let srcHeight = CGFloat(cgImage.height)
    // CIImage生成時に向きを補正
    let ciImage = CIImage(cgImage: cgImage).oriented(.up)

    // Visionの座標系（左下原点・正規化）→ CIImage座標系（左上原点・ピクセル単位）へ変換
    func visionToCI(_ point: CGPoint) -> CGPoint {
      CGPoint(x: point.x * srcWidth, y: (1 - point.y) * srcHeight)
    }
    let topLeft = visionToCI(rect.topLeft)
    let topRight = visionToCI(rect.topRight)
    let bottomLeft = visionToCI(rect.bottomLeft)
    let bottomRight = visionToCI(rect.bottomRight)

    // 射影変換フィルタ
    guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
    filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
    filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
    filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")

    let context = CIContext()
    if let outputImage = filter.outputImage {
      // 出力画像サイズを矩形のアスペクト比で決定
      let widthA = topLeft.distance(to: topRight)
      let widthB = bottomLeft.distance(to: bottomRight)
      let outputWidth = max(widthA, widthB)
      let heightA = topLeft.distance(to: bottomLeft)
      let heightB = topRight.distance(to: bottomRight)
      let outputHeight = max(heightA, heightB)

      let cropped = outputImage.cropped(
        to: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
      if let cgOutput = context.createCGImage(cropped, from: cropped.extent) {
        // orientation: .up で反転・回転問題を防ぐ
        return UIImage(cgImage: cgOutput, scale: image.scale, orientation: .up)
      }
    }
    return nil
  }
}

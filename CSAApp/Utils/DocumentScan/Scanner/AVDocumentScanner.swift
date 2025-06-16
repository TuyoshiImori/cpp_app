import AVFoundation
import Combine
import UIKit

public final class AVDocumentScanner: NSObject, ObservableObject, DocumentScanner {
  @Published public var lastTorchLevel: Float = 0
  @Published public var desiredJitter: CGFloat = 100 {
    didSet { progress.completedUnitCount = Int64(desiredJitter) }
  }
  @Published public var featuresRequired = 7
  @Published public var hasTorch: Bool = false
  public let progress = Progress()

  public lazy var previewLayer: CALayer = {
    let layer = AVCaptureVideoPreviewLayer(session: captureSession)
    layer.videoGravity = .resizeAspectFill
    return layer
  }()

  private weak var delegate: DocumentScannerDelegate?
  private var isStopped = false
  private let imageCapturer: ImageCapturer
  private var rectangleFeatures: [RectangleFeature] = []
  private let captureSession = AVCaptureSession()
  private let imageQueue = DispatchQueue(label: "imageQueue")
  public var isAutoCaptureEnabled: Bool = true

  private let device: AVCaptureDevice? = {
    AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: .back
    ).devices.first
  }()

  private lazy var output: AVCaptureVideoDataOutput = {
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    captureSession.addOutput(output)
    output.connection(with: .video)?.videoOrientation = .portrait
    return output
  }()

  private let detector = CIDetector(
    ofType: CIDetectorTypeRectangle, context: nil,
    options: [
      CIDetectorAccuracy: CIDetectorAccuracyHigh,
      CIDetectorMaxFeatureCount: 10,
    ])!

  public init(
    sessionPreset: AVCaptureSession.Preset = .photo, delegate: DocumentScannerDelegate? = nil
  ) {
    imageCapturer = ImageCapturer(session: captureSession)
    self.delegate = delegate
    super.init()
    progress.completedUnitCount = Int64(desiredJitter)
    hasTorch = device?.hasTorch ?? false

    imageQueue.async {
      guard let device = self.device,
        let input = try? AVCaptureDeviceInput(device: device)
      else { return }

      try? device.lockForConfiguration()
      device.focusMode = .continuousAutoFocus
      device.unlockForConfiguration()

      self.captureSession.beginConfiguration()
      if device.supportsSessionPreset(sessionPreset) {
        self.captureSession.sessionPreset = sessionPreset
      }
      self.captureSession.addInput(input)
      self.captureSession.commitConfiguration()
      self.captureSession.startRunning()
      self.output.setSampleBufferDelegate(self, queue: self.imageQueue)
    }
  }

  public func setDelegate(_ delegate: DocumentScannerDelegate) {
    self.delegate = delegate
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension AVDocumentScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard isStopped == false,
      CMSampleBufferIsValid(sampleBuffer),
      let buffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }

    let image = CIImage(cvImageBuffer: buffer)
    let feature = detector.features(in: image)
      .compactMap { $0 as? CIRectangleFeature }
      .map(RectangleFeature.init)  // ここでCIRectangleFeatureから初期化
      .max()
      .map {
        $0.normalized(
          source: image.extent.size,
          target: UIScreen.main.bounds.size)
      }
      .flatMap { smooth(feature: $0, in: image) }

    DispatchQueue.main.async {
      self.delegate?.didRecognize(feature: feature, in: image)
    }
  }

  func smooth(feature: RectangleFeature?, in image: CIImage) -> RectangleFeature? {
    guard let feature = feature else { return nil }

    let smoothed = feature.smoothed(with: &rectangleFeatures)
    progress.totalUnitCount = Int64(rectangleFeatures.jitter)

    if rectangleFeatures.count > featuresRequired,
      rectangleFeatures.jitter < desiredJitter,
      isStopped == false,
      let delegate = delegate
    {
      if isAutoCaptureEnabled {
        pause()  // ← 自動撮影だけ止めたい場合はここでpause()
        captureImage(in: smoothed) { [weak delegate] image in
          delegate?.didCapture(image: image)
        }
      }
      // isAutoCaptureEnabled == false のときはpauseもcaptureImageも呼ばない
      // これで矩形検出は継続
    }

    return smoothed
  }
}

// MARK: - DocumentScanner
extension AVDocumentScanner {
  public func captureImage(in bounds: RectangleFeature?, completion: @escaping (UIImage) -> Void) {
    imageCapturer.captureImage(in: bounds, completion: completion)
  }

  public func start() {
    imageQueue.async {
      self.isStopped = false  // ★ここを必ず実行
      if !self.captureSession.isRunning {
        self.captureSession.startRunning()
      }
    }
  }

  public func pause() {
    isStopped = true
  }

  public func stop() {
    guard captureSession.isRunning else { return }
    captureSession.stopRunning()
  }
}

// MARK: - TorchPickerViewDelegate
extension AVDocumentScanner: TorchPickerViewDelegate {
  func toggleTorch() {
    do {
      try device?.lockForConfiguration()
      if device?.torchMode == .off {
        let level = lastTorchLevel != 0 ? lastTorchLevel : 0.5
        try device?.setTorchModeOn(level: level)
        lastTorchLevel = level
      } else {
        device?.torchMode = .off
        lastTorchLevel = 0
      }
      device?.unlockForConfiguration()
    } catch {}
  }

  func didPickTorchLevel(_ level: Float) {
    lastTorchLevel = level
    do {
      try device?.lockForConfiguration()
      if level == 0 {
        device?.torchMode = .off
        lastTorchLevel = 0
      } else {
        try device?.setTorchModeOn(level: level)
      }
      device?.unlockForConfiguration()
    } catch {}
  }
}

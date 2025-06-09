import AVFoundation
import CoreImage
import SwiftUI
import Vision

public struct CameraView: View {
  @Binding var image: UIImage?
  @Environment(\.dismiss) private var dismiss
  @State private var isManualMode = true
  @StateObject private var cameraModel = CameraModel()

  public init(image: Binding<UIImage?>) {
    self._image = image
  }

  public var body: some View {
    ZStack {
      CameraPreview(session: cameraModel.session)
        .ignoresSafeArea()

      // 検出した矩形をオーバーレイ表示（四隅が取得できていれば台形で描画）
      if let quad = cameraModel.detectedQuad {
        QuadOverlay(quad: quad)
      } else if let rect = cameraModel.detectedRect {
        RectangleOverlay(rect: rect)
      }

      VStack(spacing: 0) {
        // ヘッダー
        HStack {
          Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 24))
              .padding(.leading, 16)
              .padding(.vertical, 8)
          }
          Spacer()
          Button(action: { isManualMode.toggle() }) {
            Text(isManualMode ? "手動" : "自動")
              .foregroundColor(.white)
              .font(.headline)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .cornerRadius(16)
          }
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(
          (cameraModel.detectedQuad != nil || cameraModel.detectedRect != nil)
            ? Color.green.opacity(0.7)
            : Color.black.opacity(0.5)
        )
        .padding(.top, 0)
        .ignoresSafeArea(edges: .horizontal)
        .padding(.top, getSafeAreaTop())

        Spacer()
        // 撮影ボタン（手動モード時のみ表示）
        if isManualMode {
          Button(action: {
            cameraModel.capturePhoto()
          }) {
            ZStack {
              Circle().stroke(Color.white, lineWidth: 4).frame(width: 74, height: 74)
              Circle().fill(Color.black).frame(width: 70, height: 70)
              Circle().fill(Color.white).frame(width: 66, height: 66).shadow(radius: 2)
            }
          }
          .padding(.bottom, 50)
        }
      }
    }
    .onAppear {
      cameraModel.onPhotoCapture = { uiImage in
        self.image = uiImage
        dismiss()
      }
      cameraModel.startSession(isAuto: !isManualMode)
    }
    .onDisappear {
      cameraModel.stopSession()
    }
    .onChange(of: isManualMode) { newValue in
      cameraModel.startSession(isAuto: !newValue)
    }
  }
}

// カメラ映像を表示するUIViewラッパー
struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = UIScreen.main.bounds
    view.layer.addSublayer(previewLayer)
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}
}

// 検出した矩形をオーバーレイ表示するView（矩形）
struct RectangleOverlay: View {
  let rect: CGRect
  var body: some View {
    GeometryReader { geo in
      Rectangle()
        .stroke(Color.green, lineWidth: 3)
        .frame(
          width: rect.width * geo.size.width,
          height: rect.height * geo.size.height
        )
        .position(
          x: rect.midX * geo.size.width,
          y: rect.midY * geo.size.height
        )
    }
    .allowsHitTesting(false)
  }
}

// 検出した四隅で台形を描画するView
struct QuadOverlay: View {
  let quad: [CGPoint]
  var body: some View {
    GeometryReader { geo in
      Path { path in
        guard quad.count == 4 else { return }
        path.move(to: CGPoint(x: quad[0].x * geo.size.width, y: quad[0].y * geo.size.height))
        path.addLine(to: CGPoint(x: quad[1].x * geo.size.width, y: quad[1].y * geo.size.height))
        path.addLine(to: CGPoint(x: quad[2].x * geo.size.width, y: quad[2].y * geo.size.height))
        path.addLine(to: CGPoint(x: quad[3].x * geo.size.width, y: quad[3].y * geo.size.height))
        path.closeSubpath()
      }
      .stroke(Color.green, lineWidth: 3)
    }
    .allowsHitTesting(false)
  }
}

// カメラ制御＋Visionリアルタイム矩形検出＋自動撮影＋四隅座標保持
class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let queue = DispatchQueue(label: "camera.frame.queue")
  var onPhotoCapture: ((UIImage) -> Void)?
  @Published var detectedRect: CGRect? = nil
  @Published var detectedQuad: [CGPoint]? = nil

  private var isAutoMode = false
  private var autoCaptureCooldown = false

  override init() {
    super.init()
    configure()
  }

  private func preprocess(pixelBuffer: CVPixelBuffer) -> CGImage? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    // グレースケール化
    let grayscale = ciImage.applyingFilter("CIPhotoEffectMono")
    // コントラスト強調
    let contrasted = grayscale.applyingFilter(
      "CIColorControls",
      parameters: [
        kCIInputContrastKey: 2.0
      ])
    let context = CIContext()
    return context.createCGImage(contrasted, from: contrasted.extent)
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
    videoOutput.setSampleBufferDelegate(self, queue: queue)
    session.commitConfiguration()
  }

  func startSession(isAuto: Bool) {
    isAutoMode = isAuto
    autoCaptureCooldown = false
    if !session.isRunning {
      DispatchQueue.global(qos: .userInitiated).async {
        self.session.startRunning()
      }
    }
  }

  func stopSession() {
    if session.isRunning {
      session.stopRunning()
    }
  }

  func capturePhoto() {
    let settings = AVCapturePhotoSettings()
    output.capturePhoto(with: settings, delegate: self)
  }

  // 手動撮影時
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    guard let data = photo.fileDataRepresentation(),
      let uiImage = UIImage(data: data)
    else { return }
    // 手動時も矩形検出してクロップ
    detectDocument(in: uiImage)
  }

  // リアルタイム矩形検出（自動モード時のみ）
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard isAutoMode, !autoCaptureCooldown,
      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }

    guard let processedCGImage = preprocess(pixelBuffer: pixelBuffer) else { return }

    let request = VNDetectRectanglesRequest { [weak self] req, _ in
      guard let self = self else { return }
      if let result = req.results?.first as? VNRectangleObservation {
        // 四隅座標を保持（0:topLeft, 1:topRight, 2:bottomRight, 3:bottomLeft）
        let quad = [
          result.topLeft,
          result.topRight,
          result.bottomRight,
          result.bottomLeft,
        ]
        DispatchQueue.main.async {
          self.detectedQuad = quad
          self.detectedRect = CGRect(
            x: result.boundingBox.origin.x,
            y: 1 - result.boundingBox.origin.y - result.boundingBox.size.height,
            width: result.boundingBox.size.width,
            height: result.boundingBox.size.height
          )
        }
        // 一定条件で自動撮影
        if result.confidence > 0.9 && result.boundingBox.width > 0.5
          && result.boundingBox.height > 0.3
        {
          self.autoCaptureCooldown = true
          self.capturePhoto()
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.autoCaptureCooldown = false
          }
        }
      } else {
        DispatchQueue.main.async {
          self.detectedQuad = nil
          self.detectedRect = nil
        }
      }
    }
    request.minimumConfidence = 0.5
    request.minimumAspectRatio = 0.2
    let handler = VNImageRequestHandler(
      cgImage: processedCGImage, orientation: .up, options: [:])
    try? handler.perform([request])
  }

  // 撮影画像から矩形検出してクロップ
  private func detectDocument(in image: UIImage) {
    guard let cgImage = image.cgImage else {
      DispatchQueue.main.async { self.onPhotoCapture?(image) }
      return
    }
    let request = VNDetectRectanglesRequest { [weak self] req, _ in
      guard let self = self else { return }
      if let result = req.results?.first as? VNRectangleObservation {
        let cropped = self.perspectiveCrop(image: image, rect: result)
        DispatchQueue.main.async { self.onPhotoCapture?(cropped ?? image) }
      } else {
        DispatchQueue.main.async { self.onPhotoCapture?(image) }
      }
    }
    request.minimumConfidence = 0.7
    request.minimumAspectRatio = 0.3
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try? handler.perform([request])
  }

  // 台形補正クロップ（CIPerspectiveCorrectionを利用）
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

// セーフエリア上部取得
private func getSafeAreaTop() -> CGFloat {
  let scenes = UIApplication.shared.connectedScenes
  let windowScene = scenes.first { $0 is UIWindowScene } as? UIWindowScene
  let window = windowScene?.windows.first
  return window?.safeAreaInsets.top ?? 0
}

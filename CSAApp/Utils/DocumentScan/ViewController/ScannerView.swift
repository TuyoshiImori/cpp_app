import AVFoundation
import SwiftUI

// SwiftUI版 ScannerView
struct ScannerView: View {
  @ObservedObject var scanner: AVDocumentScanner
  var config: ScannerConfig

  @State private var braceColor: Color = .red
  @State private var previewColor: Color = .green
  @State private var showTorchPicker: Bool = false
  @State private var torchLevel: Float = 0
  @State private var progress: Float = 0.0
  @State private var recognizedFeature: RectangleFeature?

  // 画像取得時の処理
  var onCapture: (UIImage) -> Void

  public init(
    scanner: AVDocumentScanner,
    config: ScannerConfig = .all,
    onCapture: @escaping (UIImage) -> Void
  ) {
    self.scanner = scanner
    self.config = config
    self.onCapture = onCapture
  }

  var body: some View {
    ZStack {
      CameraPreview(
        scanner: scanner,
        recognizedFeature: $recognizedFeature,
        previewColor: $previewColor
      )
      .edgesIgnoringSafeArea(.all)

      if config.showTargetBraces {
        TargetBraceView(color: braceColor)
          .frame(width: 200, height: 200)
          .position(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY + 50)
      }

      if config.manualCapture {
        VStack {
          Spacer()
          TriggerView(isHighlighted: false)
            .frame(width: 80, height: 80)
            .onTapGesture {
              capture()
            }
            .padding(.bottom, 32)
        }
      }

      HStack {
        if config.showTorch && scanner.hasTorch {
          Button(action: {
            showTorchPicker.toggle()
          }) {
            Image(systemName: torchLevel == 0 ? "flashlight.off.fill" : "flashlight.on.fill")
              .resizable()
              .frame(width: 32, height: 32)
              .foregroundColor(torchLevel == 0 ? .gray : .yellow)
              .padding()
              .background(Color.white.opacity(0.7))
              .clipShape(Circle())
          }
          .padding(.leading, 24)
        }
        Spacer()
      }
      .padding(.top, 40)

      if showTorchPicker {
        TorchPickerView(
          torchLevel: $torchLevel,
          hasTorch: scanner.hasTorch,
          onLevelChange: { level in
            scanner.didPickTorchLevel(level)
          },
          onDismiss: {
            showTorchPicker = false
          }
        )
        .frame(width: 80, height: 200)
        .position(x: UIScreen.main.bounds.width - 60, y: 180)
      }

      if config.showProgressBar {
        VStack {
          ProgressView(value: progress)
            .progressViewStyle(LinearProgressViewStyle())
            .frame(height: 4)
            .padding(.top, 8)
          Spacer()
        }
      }
    }
    .onAppear {
      scanner.setDelegate(
        ScannerDelegateProxy(
          onCapture: { image in
            scanner.pause()
            onCapture(image)  // 画像取得時の処理
          },
          onRecognize: { feature, _ in
            recognizedFeature = feature
          }
        )
      )
      scanner.start()
    }
    .onDisappear {
      scanner.stop()
    }
    .onChange(of: scanner.progress.fractionCompleted) { oldValue, newValue in
      progress = Float(newValue)
    }
    .onReceive(scanner.$lastTorchLevel) { level in
      torchLevel = level
    }
  }

  private func capture() {
    scanner.captureImage(in: config.showTargetBraces ? RectangleFeature() : nil) { image in
      scanner.pause()
      onCapture(image)  // 画像取得時の処理
    }
  }
}

// カメラプレビュー＋矩形検出オーバーレイ
struct CameraPreview: UIViewRepresentable {
  let scanner: AVDocumentScanner
  @Binding var recognizedFeature: RectangleFeature?
  @Binding var previewColor: Color

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    scanner.previewLayer.frame = UIScreen.main.bounds
    view.layer.addSublayer(scanner.previewLayer)

    // 検出矩形用のCAShapeLayer
    let detectionLayer = CAShapeLayer()
    detectionLayer.fillColor = UIColor(previewColor).withAlphaComponent(0.3).cgColor
    detectionLayer.strokeColor = UIColor(previewColor).withAlphaComponent(0.9).cgColor
    detectionLayer.lineWidth = 2
    detectionLayer.contentsGravity = .resizeAspectFill
    detectionLayer.frame = UIScreen.main.bounds
    detectionLayer.path = nil
    view.layer.addSublayer(detectionLayer)
    context.coordinator.detectionLayer = detectionLayer
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    if let feature = recognizedFeature {
      context.coordinator.detectionLayer?.path = feature.bezierPath.cgPath
    } else {
      context.coordinator.detectionLayer?.path = nil
    }

    if previewColor == .clear {
      context.coordinator.detectionLayer?.fillColor = UIColor.clear.cgColor
      context.coordinator.detectionLayer?.strokeColor = UIColor.clear.cgColor
    } else {
      context.coordinator.detectionLayer?.fillColor =
        UIColor(previewColor).withAlphaComponent(0.3).cgColor
      context.coordinator.detectionLayer?.strokeColor =
        UIColor(previewColor).withAlphaComponent(0.9).cgColor
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator {
    var detectionLayer: CAShapeLayer?
  }
}

// DocumentScannerDelegateをSwiftUIクロージャでラップ
class ScannerDelegateProxy: NSObject, DocumentScannerDelegate {
  let onCapture: (UIImage) -> Void
  let onRecognize: (RectangleFeature?, CIImage) -> Void

  init(
    onCapture: @escaping (UIImage) -> Void,
    onRecognize: @escaping (RectangleFeature?, CIImage) -> Void
  ) {
    self.onCapture = onCapture
    self.onRecognize = onRecognize
  }

  func didCapture(image: UIImage) {
    onCapture(image)
  }

  func didRecognize(feature: RectangleFeature?, in image: CIImage) {
    onRecognize(feature, image)
  }
}

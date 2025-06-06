import AVFoundation
import SwiftUI

public struct CameraView: View {
  @Binding var image: UIImage?
  @Environment(\.dismiss) private var dismiss

  @State private var isCaptureButtonVisible = true
  @StateObject private var cameraModel = CameraModel()

  public init(image: Binding<UIImage?>) {
    self._image = image
  }

  public var body: some View {
    ZStack {
      CameraPreview(session: cameraModel.session)
        .ignoresSafeArea()

      VStack {
        HStack {
          Spacer()
          Button(action: {
            isCaptureButtonVisible.toggle()
          }) {
            Image(systemName: isCaptureButtonVisible ? "eye.slash" : "eye")
              .font(.system(size: 30))
              .padding()
              .background(.ultraThinMaterial, in: Circle())
          }
          .padding()
        }
        Spacer()
        if isCaptureButtonVisible {
          Button(action: {
            cameraModel.capturePhoto()
          }) {
            Circle()
              .fill(Color.white)
              .frame(width: 70, height: 70)
              .overlay(Circle().stroke(Color.gray, lineWidth: 2))
              .shadow(radius: 4)
          }
          .padding(.bottom, 40)
        }
      }
    }
    .onAppear {
      cameraModel.startSession()
      cameraModel.onPhotoCapture = { uiImage in
        self.image = uiImage
        dismiss()
      }
    }
    .onDisappear {
      cameraModel.stopSession()
    }
  }
}

// カメラプレビュー用UIView
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

// カメラ制御用クラス
class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
  let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  var onPhotoCapture: ((UIImage) -> Void)?

  override init() {
    super.init()
    configure()
  }

  private func configure() {
    session.beginConfiguration()
    guard
      let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input),
      session.canAddOutput(output)
    else {
      session.commitConfiguration()
      return
    }
    session.addInput(input)
    session.addOutput(output)
    session.commitConfiguration()
  }

  func startSession() {
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

  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    guard let data = photo.fileDataRepresentation(),
      let uiImage = UIImage(data: data)
    else { return }
    DispatchQueue.main.async {
      self.onPhotoCapture?(uiImage)
    }
  }
}

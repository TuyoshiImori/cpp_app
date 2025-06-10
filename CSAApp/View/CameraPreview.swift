import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = UIScreen.main.bounds
    view.layer.addSublayer(previewLayer)
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    // 特に何もしない
  }
}

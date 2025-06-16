import SwiftUI

public struct CameraView: View {
  @StateObject private var viewModel = CameraViewModel()
  @Binding public var image: UIImage?
  @Environment(\.dismiss) private var dismiss
  @State private var previewColor: Color = .blue

  public init(image: Binding<UIImage?>) {
    self._image = image
  }

  public var body: some View {
    ZStack {
      CameraPreview(
        scanner: viewModel.scanner,
        recognizedFeature: $viewModel.detectedFeature,
        previewColor: .constant(viewModel.isAutoCaptureEnabled ? .blue : .clear)  // ←ここを修正
      )
      .edgesIgnoringSafeArea(.all)

      VStack {
        HStack {
          Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 24))
              .padding(.leading, 16)
              .padding(.vertical, 8)
          }
          Spacer()
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.5))
        .padding(.top, getSafeAreaTop())

        Spacer()

        if !viewModel.isAutoCaptureEnabled {
          Button("再開") {
            viewModel.resumeAutoCapture()
          }
          .padding()
          .background(Color.white.opacity(0.8))
          .cornerRadius(12)
          .padding(.bottom, 40)
        }
      }
    }
  }
}

private func getSafeAreaTop() -> CGFloat {
  let scenes = UIApplication.shared.connectedScenes
  let windowScene = scenes.first { $0 is UIWindowScene } as? UIWindowScene
  let window = windowScene?.windows.first
  return window?.safeAreaInsets.top ?? 0
}

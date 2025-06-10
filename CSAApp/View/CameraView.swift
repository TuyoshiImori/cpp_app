import SwiftUI

public struct CameraView: View {
  @Binding public var image: UIImage?
  @Environment(\.dismiss) private var dismiss
  @State private var isManualMode = true
  @StateObject private var viewModel = CameraViewModel()

  public init(image: Binding<UIImage?>) {
    self._image = image
  }

  public var body: some View {
    ZStack {
      CameraPreview(session: viewModel.session)
        .ignoresSafeArea()

      if let quad = viewModel.displayQuad {
        QuadOverlay(quad: quad)
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
          (viewModel.displayQuad != nil)
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
            viewModel.capturePhoto()
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
      viewModel.onPhotoCapture = { uiImage in
        self.image = uiImage
        dismiss()
      }
      viewModel.startSession(isAuto: !isManualMode)
    }
    .onDisappear {
      viewModel.stopSession()
    }
    .onChange(of: isManualMode) { newValue in
      viewModel.startSession(isAuto: !newValue)
    }
  }
}

// セーフエリア上部取得
private func getSafeAreaTop() -> CGFloat {
  let scenes = UIApplication.shared.connectedScenes
  let windowScene = scenes.first { $0 is UIWindowScene } as? UIWindowScene
  let window = windowScene?.windows.first
  return window?.safeAreaInsets.top ?? 0
}

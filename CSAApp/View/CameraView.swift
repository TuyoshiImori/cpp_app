import SwiftUI

public struct CameraView: View {
  @StateObject private var viewModel = CameraViewModel()
  @Binding public var image: UIImage?
  @Environment(\.dismiss) private var dismiss

  @State private var capturedImages: [UIImage] = []
  @State private var isPreviewPresented: Bool = false
  @State private var previewIndex: Int = 0

  // セーフエリア取得
  private var safeAreaInsets: UIEdgeInsets {
    UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
  }

  public init(image: Binding<UIImage?>) {
    self._image = image
  }

  public var body: some View {
    ZStack {
      CameraPreview(
        scanner: viewModel.scanner,
        recognizedFeature: $viewModel.detectedFeature,
        previewColor: .constant(viewModel.isAutoCaptureEnabled ? .blue : .clear)
      )
      .edgesIgnoringSafeArea(.all)

      // 上部バー
      VStack {
        HStack {
          Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 24, weight: .bold))
              .foregroundColor(.white)
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
      }

      // 左下サムネイル（最後の画像のみ、セーフエリア考慮）
      VStack {
        Spacer()
        HStack {
          if let lastImage = capturedImages.last {
            Button(action: {
              previewIndex = capturedImages.count - 1
              isPreviewPresented = true
            }) {
              Image(uiImage: lastImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 2)
                )
                .padding(.leading, 8 + safeAreaInsets.left)
                .padding(.bottom, 16 + safeAreaInsets.bottom)
            }
          }
          Spacer()
        }
      }
      .edgesIgnoringSafeArea(.bottom)

      // 右下再開ボタン
      VStack {
        Spacer()
        HStack {
          Spacer()
          if !viewModel.isAutoCaptureEnabled {
            Button(action: {
              viewModel.resumeAutoCapture()
            }) {
              Text("再開")
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.9))
                .cornerRadius(24)
            }
            .padding(.bottom, 24 + safeAreaInsets.bottom)
            .padding(.trailing, 16 + safeAreaInsets.right)
          }
        }
      }
      .edgesIgnoringSafeArea(.bottom)
    }
    // 全画面プレビュー（スワイプで切り替え）
    .fullScreenCover(isPresented: $isPreviewPresented) {
      ZStack(alignment: .topTrailing) {
        Color.black.ignoresSafeArea()
        if !capturedImages.isEmpty {
          TabView(selection: $previewIndex) {
            ForEach(Array(capturedImages.enumerated()), id: \.offset) { idx, img in
              Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .tag(idx)
                .background(Color.black)
            }
          }
          .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
          .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
        Button(action: { isPreviewPresented = false }) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 36))
            .foregroundColor(.white)
            .padding()
        }
      }
    }
    // 撮影画像をViewModelから受け取る
    .onReceive(viewModel.$capturedImage.compactMap { $0 }) { img in
      capturedImages.append(img)
      image = img
    }
  }
}

private func getSafeAreaTop() -> CGFloat {
  let scenes = UIApplication.shared.connectedScenes
  let windowScene = scenes.first { $0 is UIWindowScene } as? UIWindowScene
  let window = windowScene?.windows.first
  return window?.safeAreaInsets.top ?? 0
}

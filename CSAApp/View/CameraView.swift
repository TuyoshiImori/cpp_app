import SwiftUI
import Vision

public struct CameraView: View {
  @StateObject private var viewModel = CameraViewModel()
  @Binding public var image: UIImage?
  @Environment(\.dismiss) private var dismiss

  @State private var capturedImages: [UIImage] = []
  @State private var isPreviewPresented: Bool = false
  @State private var previewIndex: Int = 0
  @State private var recognizedTexts: [Int: [VNRecognizedTextObservation]] = [:]

  // セーフエリア取得
  private var safeAreaInsets: UIEdgeInsets {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    else {
      return .zero
    }
    return window.safeAreaInsets
  }

  // Item情報を受け取るプロパティを追加
  public var item: Item?

  public init(image: Binding<UIImage?>, item: Item? = nil) {
    self._image = image
    self.item = item
  }

  // 全画面プレビュー部分をサブViewに分離
  private func previewFullScreenView() -> some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()
      if !capturedImages.isEmpty {
        TabView(selection: $previewIndex) {
          ForEach(Array(capturedImages.enumerated()), id: \.offset) { idx, img in
            ZStack {
              Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .tag(idx)
                .background(Color.black)
              VStack {
                Spacer()
                let textObs = recognizedTexts[idx] ?? []
                ScrollView(.vertical, showsIndicators: true) {
                  VStack(alignment: .leading, spacing: 4) {
                    if textObs.isEmpty {
                      Text("文字が検出されませんでした")
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                    } else {
                      ForEach(textObs, id: \.uuid) { obs in
                        if let candidate = obs.topCandidates(1).first {
                          Text(candidate.string)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                        }
                      }
                    }
                  }
                  .padding(.bottom, 32)
                  .padding(.horizontal, 12)
                }
              }
            }
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
          if let item = item {
            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
              .foregroundColor(.white)
              .font(.headline)
              .padding(.trailing, 16)
          }
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
      previewFullScreenView()
    }
    // 撮影画像をViewModelから受け取る
    .onReceive(viewModel.$capturedImage.compactMap { $0 }) { (img: UIImage) in
      capturedImages.append(img.toGrayscaleOnly() ?? img)
      image = img.toGrayscaleOnly() ?? img
      recognizeText(in: img.toGrayscaleOnly() ?? img, index: capturedImages.count - 1)
    }
  }

  private func getSafeAreaTop() -> CGFloat {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    else {
      return 0
    }
    return window.safeAreaInsets.top
  }

  // OCR処理: 画像内のテキストを検出しrecognizedTextsに格納
  private func recognizeText(in image: UIImage, index: Int) {
    guard let cgImage = image.cgImage else { return }
    let request = VNRecognizeTextRequest { request, error in
      if let results = request.results as? [VNRecognizedTextObservation] {
        DispatchQueue.main.async {
          recognizedTexts[index] = results
        }
      }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["ja-JP", "en-US"]  // 日本語と英語を優先
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      try? handler.perform([request])
    }
  }
}

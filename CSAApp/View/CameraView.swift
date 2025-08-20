import SwiftUI
import Vision

public struct CameraView: View {
  @StateObject private var viewModel: CameraViewModel
  @Binding public var image: UIImage?
  @Environment(\.dismiss) private var dismiss

  @State private var capturedImages: [UIImage] = []
  @State private var croppedImageSets: [[UIImage]] = []  // 各キャプチャごとの切り取り画像セット
  @State private var isPreviewPresented: Bool = false
  @State private var previewIndex: Int = 0
  @State private var recognizedTexts: [[String]] = []  // 各画像ごとの認識された文字列
  @State private var isCircleDetectionFailed: Bool = false

  // セーフエリア取得
  private var safeAreaInsets: UIEdgeInsets {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    else {
      return .zero
    }
    return window.safeAreaInsets
  }

  public var item: Item?

  public init(image: Binding<UIImage?>, item: Item? = nil) {
    self._image = image
    self.item = item
    if let item = item {
      _viewModel = StateObject(wrappedValue: CameraViewModel(questionTypes: item.questionTypes))
    } else {
      _viewModel = StateObject(wrappedValue: CameraViewModel())
    }
  }

  // プレビュー全画面表示
  private func previewFullScreenView() -> some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()
      if !croppedImageSets.isEmpty {
        TabView(selection: $previewIndex) {
          ForEach(Array(croppedImageSets.enumerated()), id: \.offset) { setIdx, imageSet in
            GeometryReader { geo in
              ScrollView(.vertical) {
                VStack(spacing: 10) {
                  ForEach(Array(imageSet.enumerated()), id: \.offset) { imgIdx, img in
                    VStack {
                      Text("設問 \(imgIdx + 1)つ目")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.top, 10)

                      Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width - 20)
                        .padding(.horizontal, 10)
                    }
                  }
                }
                .padding(.top, 50)
              }
            }
            .tag(setIdx)
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
          if let lastImageSet = croppedImageSets.last, let firstImage = lastImageSet.first {
            Button(action: {
              previewIndex = croppedImageSets.count - 1
              isPreviewPresented = true
            }) {
              Image(uiImage: firstImage)
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

      // サンプル画像読み込みボタン
      VStack {
        HStack {
          Spacer()
          Button(action: {
            let sample1 = UIImage(named: "form", in: Bundle.main, compatibleWith: nil)
            let sample2 = UIImage(named: "form")
            let loadedSample = sample1 ?? sample2
            if let sample = loadedSample {
              let (graySample, texts) = sample.recognizeTextWithVisionSync()
              let croppedImages = sample.cropImagesByCircles()

              capturedImages.append(graySample)
              croppedImageSets.append(croppedImages)
              recognizedTexts.append(texts)
              image = graySample
            }
          }) {
            HStack(spacing: 8) {
              Image(systemName: "photo.on.rectangle")
              Text("サンプル読み込み")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(16)
            .shadow(radius: 4)
          }
          .padding(.top, 16 + safeAreaInsets.top)
          .padding(.trailing, 16)
        }
        Spacer()
      }

      .alert(isPresented: $isCircleDetectionFailed) {
        Alert(
          title: Text("スキャン失敗"),
          message: Text("適切なフォーマットのアンケートをスキャンしてください。"),
          dismissButton: .default(Text("OK"))
        )
      }
    }
    .fullScreenCover(isPresented: $isPreviewPresented) {
      previewFullScreenView()
    }
    .onReceive(viewModel.$capturedImage.compactMap { $0 }) { (img: UIImage) in
      let (gray, texts) = img.recognizeTextWithVisionSync()
      let croppedImages = img.cropImagesByCircles()

      if croppedImages.isEmpty {
        isCircleDetectionFailed = true
      } else {
        capturedImages.append(gray)
        croppedImageSets.append(croppedImages)
        recognizedTexts.append(texts)
        image = gray
      }
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
}

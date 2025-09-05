import SwiftUI
import Vision

#if canImport(UIKit)
  import UIKit
#endif

public struct CameraView: View {
  @StateObject private var viewModel: CameraViewModel
  @Binding public var image: UIImage?
  @Environment(\.dismiss) private var dismiss

  @State private var capturedImages: [UIImage] = []
  @State private var croppedImageSets: [[UIImage]] = []  // 各キャプチャごとの切り取り画像セット
  @State private var parsedResults: [[String]] = []  // 各キャプチャごとの解析結果（parsedAnswers）
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
                    // 安全に検出文字列を取り出す
                    let detectedOpt: String? =
                      (parsedResults.indices.contains(setIdx)
                        && parsedResults[setIdx].indices.contains(imgIdx))
                      ? parsedResults[setIdx][imgIdx] : nil
                    let displayText = displayTextFor(
                      setIdx: setIdx, imgIdx: imgIdx, detectedOptional: detectedOpt)

                    PreviewImageCell(
                      title: "設問 \(imgIdx + 1)つ目", image: img, displayText: displayText
                    )
                    .frame(maxWidth: geo.size.width - 20)
                    .padding(.horizontal, 10)
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
          // アンケートのタイトルとタイムスタンプを表示
          if let item = item {
            VStack(alignment: .trailing, spacing: 2) {
              if !item.title.isEmpty {
                Text(item.title)
                  .foregroundColor(.white)
                  .font(.headline)
                  .bold()
                  .lineLimit(1)
                  .truncationMode(.tail)
              }
              HStack(spacing: 8) {
                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                  .foregroundColor(.white.opacity(0.85))
                  .font(.subheadline)
              }
            }
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

              // item の StoredType を文字列配列へ変換して OpenCV に渡す
              var storedTypes: [String] = []
              if let item = item {
                storedTypes = item.questionTypes.map { qt in
                  switch qt {
                  case .single: return "single"
                  case .multiple: return "multiple"
                  case .text: return "text"
                  case .info: return "info"
                  }
                }
              }

              // まず切り取りだけを取得し、その切り取り画像リストと storedTypes を
              // 明示的に OpenCV 側に渡して解析を行う
              let base = OpenCVWrapper.detectCirclesAndCrop(sample)
              let baseCropped = base?["croppedImages"] as? [UIImage] ?? [sample]
              let (_, _, croppedImages, parsed) = sample.processWithOpenCVAndParsedAnswers(
                storedTypes: storedTypes)

              capturedImages.append(graySample)
              croppedImageSets.append(croppedImages)
              parsedResults.append(parsed)
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
      // item の StoredType を文字列配列へ変換して OpenCV に渡す
      var storedTypes: [String] = []
      if let item = item {
        storedTypes = item.questionTypes.map { qt in
          switch qt {
          case .single: return "single"
          case .multiple: return "multiple"
          case .text: return "text"
          case .info: return "info"
          }
        }
      }

      // 既存画像についても同様に、まず切り取りを取得してから解析を行う
      let base = OpenCVWrapper.detectCirclesAndCrop(img)
      let baseCropped = base?["croppedImages"] as? [UIImage] ?? [img]
      let (_, _, croppedImages, parsed) = img.processWithOpenCVAndParsedAnswers(
        storedTypes: storedTypes)

      if croppedImages.isEmpty {
        isCircleDetectionFailed = true
      } else {
        capturedImages.append(gray)
        croppedImageSets.append(croppedImages)
        parsedResults.append(parsed)
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

// 小さなセルビュー: 画像と検出テキストを表示
private struct PreviewImageCell: View {
  let title: String
  let image: UIImage
  let displayText: String?

  var body: some View {
    VStack(spacing: 8) {
      Text(title)
        .foregroundColor(.white)
        .font(.headline)
        .padding(.top, 10)

      Image(uiImage: image)
        .resizable()
        .scaledToFit()

      if let displayText = displayText {
        Text("検出: \(displayText)")
          .foregroundColor(.white)
          .font(.subheadline)
          .padding(.bottom, 8)
      }
    }
  }
}

// 表示文字列を安全に構築する小さな関数
private func displayTextFor(setIdx: Int, imgIdx: Int, detectedOptional: String?) -> String? {
  guard let detected = detectedOptional else { return nil }
  // ここでは Item 型や questionTypes にアクセスせず単純に detected を返す
  // 追加のロジックが必要なら CameraView 内で別途処理する
  return detected
}

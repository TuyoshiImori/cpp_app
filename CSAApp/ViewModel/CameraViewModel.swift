import AVFoundation
import Combine
import UIKit

// カメラのスキャン状態を表す列挙型
enum ScanState {
  /// スキャン可能（自動キャプチャが有効で、取り込み可能な状態）
  case possible
  /// スキャン中（現在画像を解析中）
  case scanning
  /// スキャン完了・一時停止（再開可能）
  case paused
}

final class CameraViewModel: NSObject, ObservableObject {
  @Published var initialQuestionTypes: [QuestionType] = []
  @Published var capturedImage: UIImage?
  @Published var detectedFeature: RectangleFeature? = nil
  @Published var parsedAnswers: [String] = []
  @Published var lastCroppedImages: [UIImage] = []
  @Published var recognizedTexts: [String] = []
  @Published var confidenceScores: [Float] = []  // OCR信頼度スコア
  @Published var isTorchOn: Bool = false
  @Published var isTargetBracesVisible: Bool = true
  @Published var isAutoCaptureEnabled: Bool = true
  // スキャン状態を公開する（View 側はこれを監視してボタン表示を変更する）
  @Published var scanState: ScanState = .possible

  let scanner = AVDocumentScanner()

  override init() {
    super.init()
    scanner.setDelegate(self)
    scanner.start()
    isAutoCaptureEnabled = true
    scanner.isAutoCaptureEnabled = true
  }

  convenience init(questionTypes: [QuestionType]) {
    self.init()
    self.initialQuestionTypes = questionTypes
  }

  func toggleTorch() {
    scanner.toggleTorch()
    isTorchOn = scanner.lastTorchLevel > 0
  }

  func toggleTargetBraces() {
    isTargetBracesVisible.toggle()
  }

  // Cameraの自動キャプチャの一時停止と再開、手動キャプチャを行うメソッド群
  func pauseAutoCapture() {
    isAutoCaptureEnabled = false
    scanner.isAutoCaptureEnabled = false
    // 自動キャプチャを一時停止したら再開可能な状態にする
    DispatchQueue.main.async {
      self.scanState = .paused
    }
  }

  func resumeAutoCapture() {
    isAutoCaptureEnabled = true
    scanner.isAutoCaptureEnabled = true
    scanner.start()
    // 再開したらスキャン可能状態に戻す
    DispatchQueue.main.async {
      self.scanState = .possible
    }
  }

  /// 取り込んだ画像を共通処理する。
  /// カメラからの取り込みとサンプル読み込みの両方で使う。
  /// - Parameters:
  ///   - image: 入力画像
  ///   - pauseAutoCapture: true の場合、自動キャプチャを一時停止する（カメラ取り込み時は true を想定）
  func processCapturedImage(
    _ image: UIImage, completion: (() -> Void)? = nil
  ) {
    // UI の即時反映のため、状態はメインスレッドで切り替え、重い解析はバックグラウンドで行う
    DispatchQueue.main.async {
      self.scanState = .scanning
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let (gray, texts, cropped) = image.recognizeTextWithVisionSync()

      // 解析結果をメインスレッドで反映させる
      DispatchQueue.main.async {
        // 切り取った設問画像を先に保持してから capturedImage を公開する
        // -> `.onReceive(viewModel.$capturedImage)` 側が `lastCroppedImages` を参照するため、
        //    先に `lastCroppedImages` を設定してから `capturedImage` を publish する。
        self.recognizedTexts = texts
        self.lastCroppedImages = cropped
        self.capturedImage = gray

        // 自動キャプチャを一時停止
        self.pauseAutoCapture()

        let parsed = self.parseCroppedImagesWithStoredTypes(cropped)
        self.parsedAnswers = parsed

        // 完了コールバック
        completion?()

        // 画像解析が終わったのでスキャン完了（paused）状態にする
        self.scanState = .paused
      }
    }
  }

  /// initialQuestionTypes を元に types (String) と optionTexts ([[String]]) を構築し、
  /// 切り取った画像配列と共に OpenCV の解析 API を呼び出すサンプルメソッド
  func parseCroppedImagesWithStoredTypes(_ croppedImages: [UIImage]) -> [String] {
    // StoredType 文字列配列
    let types: [String] = initialQuestionTypes.map { qt in
      switch qt {
      case .single(_, _): return "single"
      case .multiple(_, _): return "multiple"
      case .text(_): return "text"
      case .info(_, _): return "info"
      }
    }

    // optionTexts を二次元配列として構築
    let optionTexts: [[String]] = initialQuestionTypes.map { qt in
      switch qt {
      case .single(_, let options): return options
      case .multiple(_, let options): return options
      case .text(_): return []
      case .info(_, let infoFields):
        // InfoField の順序をそのままネイティブ側に渡す（rawValue で識別）
        return infoFields.map { $0.rawValue }
      }
    }

    // デバッグ: Swift側でのoptionTextsの内容を確認
    print("Swift側 optionTexts:")
    for (index, texts) in optionTexts.enumerated() {
      print("  index[\(index)]: \(texts)")
    }

    // OpenCVWrapper の新 API を呼び出す
    let raw = OpenCVWrapper.parseCroppedImages(
      self.capturedImage ?? UIImage(),
      withCroppedImages: croppedImages,
      withStoredTypes: types,
      withOptionTexts: optionTexts)
    guard let parsed = raw?["parsedAnswers"] as? [String] else { return [] }
    return parsed
  }
}

extension CameraViewModel: DocumentScannerDelegate {
  func didCapture(image: UIImage) {
    // 共通処理
    self.processCapturedImage(image) {
      NSLog("CameraViewModel.didCapture: parsedAnswers=%@", self.parsedAnswers)
    }
  }

  func didRecognize(feature: RectangleFeature?, in image: CIImage) {
    DispatchQueue.main.async {
      self.detectedFeature = feature
    }
  }
}

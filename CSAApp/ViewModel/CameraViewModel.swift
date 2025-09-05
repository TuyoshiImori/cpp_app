import AVFoundation
import Combine
import UIKit

final class CameraViewModel: NSObject, ObservableObject {
  @Published var initialQuestionTypes: [QuestionType] = []
  @Published var capturedImage: UIImage?
  @Published var detectedFeature: RectangleFeature? = nil
  @Published var isTorchOn: Bool = false
  @Published var isTargetBracesVisible: Bool = true
  @Published var isAutoCaptureEnabled: Bool = true
  // OpenCV から返される解析結果（parsedAnswers）を保持する
  @Published var parsedAnswers: [String] = []

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

  func pauseAutoCapture() {
    isAutoCaptureEnabled = false
    scanner.isAutoCaptureEnabled = false
  }

  func resumeAutoCapture() {
    isAutoCaptureEnabled = true
    scanner.isAutoCaptureEnabled = true
    scanner.start()
  }

  func capturePhoto(completion: @escaping (UIImage?) -> Void) {
    scanner.captureImage(in: detectedFeature) { image in
      DispatchQueue.main.async {
        let (gray, _) = image.recognizeTextWithVisionSync()
        self.capturedImage = gray
        self.pauseAutoCapture()
        // キャプチャ後、CameraViewModel 側で選択肢数配列を作成して解析を呼び出す
        self.buildOptionCountsAndParse { result in
          // 非同期コールバックで完了ハンドラを呼ぶ
          completion(self.capturedImage)
        }
      }
    }
  }

  // MARK: - OpenCV 呼び出しヘルパー
  // initialQuestionTypes から storedTypes ("single:N" 等) と optionCounts ([Int]) を作成し
  // OpenCV に渡して解析結果(parsedAnswers) を取得して published property に格納する
  func buildOptionCountsAndParse(completion: @escaping (Bool) -> Void) {
    guard let img = self.capturedImage else {
      completion(false)
      return
    }

    // storedTypes と optionCounts を作成
    var storedTypes: [String] = []
    var optionCounts: [Int] = []
    for qt in initialQuestionTypes {
      switch qt {
      case .single(_, let options):
        let cnt = options.count
        storedTypes.append("single:\(cnt)")
        optionCounts.append(cnt)
      case .multiple(_, let options):
        let cnt = options.count
        storedTypes.append("multiple:\(cnt)")
        optionCounts.append(cnt)
      case .text(_):
        storedTypes.append("text")
        optionCounts.append(0)
      case .info(_, _):
        storedTypes.append("info")
        optionCounts.append(0)
      }
    }

    // ログ出力: 選択肢数の配列
    NSLog("CameraViewModel: optionCounts = %@", optionCounts)

    // まず切り取り処理を呼び出す
    guard let baseAny = OpenCVWrapper.detectCirclesAndCrop(img) as? [String: Any] else {
      completion(false)
      return
    }
    // 切り取り画像配列を取り出す
    var croppedImages: [UIImage] = []
    if let cis = baseAny["croppedImages"] as? [UIImage] {
      croppedImages = cis
    } else if let cis = baseAny["croppedImages"] as? NSArray {
      // NSArray -> [UIImage]
      for v in cis {
        if let ui = v as? UIImage {
          croppedImages.append(ui)
        }
      }
    }

    // OpenCV 側は storedTypes 内の "single:N" を解釈する実装になっているため
    // ここでは optionCounts を別引数で渡す代わりに storedTypes に埋め込んで渡す。
    // （将来的にネイティブ側に Int 配列を直接渡す API があればそちらに差し替え可能）
    guard
      let resultAny = OpenCVWrapper.parseCroppedImages(
        img, withCroppedImages: croppedImages, withStoredTypes: storedTypes) as? [String: Any]
    else {
      self.parsedAnswers = []
      completion(false)
      return
    }

    // parsedAnswers を取り出して Published に反映する
    if let parsed = resultAny["parsedAnswers"] as? [String] {
      self.parsedAnswers = parsed
    } else if let parsed = resultAny["parsedAnswers"] as? NSArray {
      var out: [String] = []
      for v in parsed {
        if let s = v as? String {
          out.append(s)
        } else if let n = v as? NSNumber {
          out.append(n.stringValue)
        }
      }
      self.parsedAnswers = out
    } else {
      self.parsedAnswers = []
    }

    // 簡単なログと完了通知
    NSLog("CameraViewModel: parsedAnswers = %@", self.parsedAnswers)
    completion(true)
  }
}

extension CameraViewModel: DocumentScannerDelegate {
  func didCapture(image: UIImage) {
    DispatchQueue.main.async {
      let (gray, _) = image.recognizeTextWithVisionSync()
      self.capturedImage = gray
      self.pauseAutoCapture()
    }
  }

  func didRecognize(feature: RectangleFeature?, in image: CIImage) {
    DispatchQueue.main.async {
      self.detectedFeature = feature
    }
  }
}

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
  // info設問向けに行単位の信頼度を保持する（各設問ごとに行が複数ある場合がある）
  @Published var confidenceScores2D: [[Float]] = []
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
        // 切り取った設問画像を保持してから解析を実行し、
        // 解析結果（parsedAnswers / confidenceScores）をセットしてから
        // 最後に capturedImage を publish するように順序を調整する。
        // これにより、View 側の `.onReceive(viewModel.$capturedImage)` が
        // 受け取った際に、関連する解析結果が既に揃っていることを保証する。
        self.recognizedTexts = texts
        self.lastCroppedImages = cropped

        // 自動キャプチャを一時停止
        self.pauseAutoCapture()

        // 切り出し画像を解析して parsedAnswers と confidenceScores を更新
        let parsed = self.parseCroppedImagesWithStoredTypes(cropped)
        self.parsedAnswers = parsed

        // 解析結果が揃った後でグレースケール画像を publish して、View 側で UI 更新をトリガーする
        self.capturedImage = gray

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

    // 信頼度スコアも取得して保存（OpenCV からのフラットな配列をまず格納）
    if let scores = raw?["confidenceScores"] as? [NSNumber] {
      self.confidenceScores = scores.map { $0.floatValue }
      NSLog("CameraViewModel: 信頼度スコアを取得: %@", scores)
    } else if let scores = raw?["confidenceScores"] as? [Float] {
      self.confidenceScores = scores
      NSLog("CameraViewModel: 信頼度スコアを取得 (Float array): %@", scores)
    } else {
      self.confidenceScores = []
      NSLog("CameraViewModel: 信頼度スコアが見つかりません")
    }

    // OpenCV の parsedAnswers を利用して、info 設問については
    // Vision(OCRManager) を使って行ごとの信頼度を再取得し、
    // confidenceScores2D として格納する（UIでより詳細に表示するため）
    var scores2D: [[Float]] = []
    if let parsedFromRaw = raw?["parsedAnswers"] as? [NSString], parsedFromRaw.count == parsed.count
    {
      for (idx, parsedObj) in parsedFromRaw.enumerated() {
        let parsedStr = parsedObj as String
        // OpenCV 側で info の場合は改行で行が分かれて返ってくる想定
        if types.count > idx && types[idx] == "info" {
          let lines = parsedStr.components(separatedBy: "\n")
          var lineScores: [Float] = []
          for (lineIdx, line) in lines.enumerated() {
            // 空行は 0 とする
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
              lineScores.append(0.0)
              continue
            }
            // Vision を呼んで信頼度を取得
            // OpenCV 側で行ごとの信頼度が返されていればそれを利用
            // OpenCV からの rowConfidences を安全に取り出す。期待形式は
            // NSArray of NSArray of NSNumber（Objective-C側から渡される）
            if let rowConfsAny = raw?["rowConfidences"] as? [Any],
              rowConfsAny.count > idx,
              let confidencesForThisAny = rowConfsAny[idx] as? [Any]
            {
              // confidencesForThisAny の要素を NSNumber/Float に変換して扱う
              if lineIdx < confidencesForThisAny.count {
                let valAny = confidencesForThisAny[lineIdx]
                if let num = valAny as? NSNumber {
                  lineScores.append(num.floatValue)
                } else if let f = valAny as? Float {
                  lineScores.append(f)
                } else if let d = valAny as? Double {
                  lineScores.append(Float(d))
                } else if let s = valAny as? String, let d = Double(s) {
                  lineScores.append(Float(d))
                } else {
                  lineScores.append(0.0)
                }
              } else {
                lineScores.append(0.0)
              }
            } else {
              // フォールバック: ここでは OCRManager を呼んででも信頼度を取得したいが、
              // そのためには行ごとの UIImage が必要。現状では OpenCV が行画像を
              // 直接返してくれないため、0.0 を入れておく。将来的に OpenCV 側で
              // 行ごとの UIImage を返すように拡張することを推奨。
              lineScores.append(0.0)
            }
          }
          scores2D.append(lineScores)
        } else {
          // info 以外は単一の値で扱う（既存の confidenceScores から補う）
          if idx < self.confidenceScores.count {
            scores2D.append([self.confidenceScores[idx]])
          } else {
            scores2D.append([0.0])
          }
        }
      }
      self.confidenceScores2D = scores2D
    }

    return parsed
  }

  /// info設問の表示用フォーマットを生成する。
  /// - Parameters:
  ///   - index: 設問インデックス
  ///   - parsedAnswer: OpenCVまたはOCRから得られた改行区切りの回答文字列
  /// - Returns: 各個人情報項目ごとに「設問文：回答文（信頼度：100%）」の形式で返す配列
  func formattedInfoLines(for index: Int, parsedAnswer: String) -> [String] {
    guard index < initialQuestionTypes.count else { return [] }
    let qtype = initialQuestionTypes[index]
    switch qtype {
    case .info(let questionText, let infoFields):
      // parsedAnswer は行ごとに分割されている想定
      let lines = parsedAnswer.components(separatedBy: "\n")
      var out: [String] = []
      for (i, field) in infoFields.enumerated() {
        let answer = i < lines.count ? lines[i].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        // 信頼度は confidenceScores2D に入っている可能性がある
        var confText = "信頼度: N/A"
        if index < confidenceScores2D.count {
          let row = confidenceScores2D[index]
          if i < row.count {
            confText = String(format: "信頼度: %.0f%%", row[i])
          }
        } else if index < confidenceScores.count {
          // フラットなスコアから代替でパーセント表示
          let v = confidenceScores[index]
          confText = String(format: "信頼度: %.0f%%", v)
        }

        let line = "\(field.displayName)：\(answer)（\(confText)）"
        out.append(line)
      }
      return out
    default:
      return []
    }
  }

  /// 指定インデックスの設問が info タイプかどうかを返すユーティリティ
  func isInfoQuestion(at index: Int) -> Bool {
    guard index < initialQuestionTypes.count else { return false }
    switch initialQuestionTypes[index] {
    case .info(_, _): return true
    default: return false
    }
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

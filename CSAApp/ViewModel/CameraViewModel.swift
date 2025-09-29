import AVFoundation
import Combine
import SwiftData
import SwiftUI
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
  @Published var confidenceScores: [Float] = []  // OCR信頼度スコア
  // info設問向けに行単位の信頼度を保持する（各設問ごとに行が複数ある場合がある）
  @Published var confidenceScores2D: [[Float]] = []
  @Published var isTorchOn: Bool = false
  @Published var isTargetBracesVisible: Bool = true
  @Published var isAutoCaptureEnabled: Bool = true
  // スキャン状態を公開する（View 側はこれを監視してボタン表示を変更する）
  @Published var scanState: ScanState = .possible
  /// 画像解析中かどうか（UI 側でローディングを表示するために使用）
  @Published var isProcessing: Bool = false

  /// Analysis 用の NavigationLink をトリガーするためのフラグ
  @Published var isAnalysisActive: Bool = false

  // MARK: - Data Management Properties
  /// キャプチャされた画像の配列
  @Published var capturedImages: [UIImage] = []
  /// 各キャプチャごとの切り取り画像セット
  @Published var croppedImageSets: [[UIImage]] = []
  /// 各画像ごとの認識された文字列（2次元配列）
  @Published var recognizedTextsSets: [[String]] = []
  /// 各キャプチャごとの信頼度スコアセット
  @Published var confidenceScoreSets: [[Float]] = []

  // MARK: - UI State Properties
  /// プレビューが表示されているかどうか
  @Published var isPreviewPresented: Bool = false
  /// プレビューのインデックス
  @Published var previewIndex: Int = 0
  /// サンプル処理中かどうか
  @Published var isProcessingSample: Bool = false
  /// パルスアニメーションが有効かどうか
  @Published var isPulseActive: Bool = false
  /// 円検出が失敗したかどうか
  @Published var isCircleDetectionFailed: Bool = false

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

  /// スキャン結果をItemに保存するメソッド（新しいScanResult構造を使用）
  /// - Parameters:
  ///   - item: 保存対象のItem
  ///   - croppedImages: 切り取られた設問画像の配列
  ///   - parsedAnswers: 解析された回答文字列の配列
  ///   - confidenceScores: 信頼度スコアの配列
  func saveResultsToItem(
    _ item: Item, croppedImages: [UIImage], parsedAnswers: [String], confidenceScores: [Float]
  ) {
    // 切り取り画像をData形式に変換
    let imageDataArray = croppedImages.map { image in
      // JPEG形式で圧縮（品質0.8でバランスを取る）
      return image.jpegData(compressionQuality: 0.8)
    }

    // 新しいScanResultを作成（2D信頼度も保存）
    let scanResult = ScanResult(
      scanID: UUID().uuidString,
      timestamp: Date(),
      confidenceScores: confidenceScores,
      confidenceScores2D: self.confidenceScores2D,
      answerTexts: parsedAnswers,
      questionImageData: imageDataArray
    )

    // ItemにScanResultを追加
    item.addScanResult(scanResult)

    // 後方互換性のため、最新の結果を古いプロパティにも保存
    item.answerTexts = parsedAnswers
    item.confidenceScores = confidenceScores
    item.questionImageData = imageDataArray
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
      // ローディング開始
      self.isProcessing = true
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
        self.lastCroppedImages = cropped

        // 自動キャプチャを一時停止
        self.pauseAutoCapture()

        // 切り出し画像を解析して parsedAnswers と confidenceScores を更新
        // OpenCV 呼び出しには今回解析対象のフル画像を渡す。
        let parsed = self.parseCroppedImagesWithStoredTypes(cropped, fullImage: gray)
        self.parsedAnswers = parsed

        // 解析結果が揃った後でグレースケール画像を publish して、View 側で UI 更新をトリガーする
        self.capturedImage = gray

        // ローディング解除（解析完了）
        self.isProcessing = false

        // 完了コールバック
        completion?()

        // 画像解析が終わったのでスキャン完了（paused）状態にする
        self.scanState = .paused
      }
    }
  }

  /// initialQuestionTypes を元に types (String) と optionTexts ([[String]]) を構築し、
  /// 切り取った画像配列と共に OpenCV の解析 API を呼び出すサンプルメソッド
  func parseCroppedImagesWithStoredTypes(_ croppedImages: [UIImage], fullImage: UIImage) -> [String]
  {
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

    // OpenCVWrapper の新 API を呼び出す
    let raw = OpenCVWrapper.parseCroppedImages(
      fullImage,
      withCroppedImages: croppedImages,
      withStoredTypes: types,
      withOptionTexts: optionTexts)
    guard let parsed = raw?["parsedAnswers"] as? [String] else { return [] }

    // 信頼度スコアも取得して保存（OpenCV からのフラットな配列をまず格納）
    if let scores = raw?["confidenceScores"] as? [NSNumber] {
      self.confidenceScores = scores.map { $0.floatValue }
    } else if let scores = raw?["confidenceScores"] as? [Float] {
      self.confidenceScores = scores
    } else {
      self.confidenceScores = []
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
    case .info(_, let infoFields):
      // parsedAnswer は行ごとに分割されている想定
      let lines = parsedAnswer.components(separatedBy: "\n")
      var out: [String] = []
      for (i, field) in infoFields.enumerated() {
        let answer = i < lines.count ? lines[i].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let line = "\(field.displayName)：\(answer)"
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

// MARK: - Data Management Methods
extension CameraViewModel {
  /// 保存されたスキャンデータを復元してUIに表示する
  func loadExistingData(for item: Item?) {
    guard let item = item else { return }
    // 既存のUI配列をクリアしてから復元する（重複追加防止）
    croppedImageSets = []
    recognizedTextsSets = []
    confidenceScoreSets = []

    // 保存されたすべてのScanResultを復元してUI配列に追加する
    var allCroppedSets: [[UIImage]] = []
    var allRecognized: [[String]] = []
    var allConfidences: [[Float]] = []

    // まず新しいScanResult配列から復元
    for scan in item.scanResults {
      let imgs = scan.getAllQuestionImages().compactMap { $0 }
      if !imgs.isEmpty {
        allCroppedSets.append(imgs)
        allRecognized.append(scan.answerTexts)
        // 2D信頼度が存在する場合は設問ごとの平均値を計算して使用
        if !scan.confidenceScores2D.isEmpty {
          let flattenedConfidences = scan.confidenceScores2D.map { rows -> Float in
            if rows.isEmpty { return 0.0 }
            let sum = rows.reduce(0.0, +)
            return sum / Float(rows.count)
          }
          allConfidences.append(flattenedConfidences)
        } else {
          allConfidences.append(scan.confidenceScores)
        }
      }
    }

    // 新しい構造が空の場合は古いプロパティから復元しておく（後方互換）
    if allCroppedSets.isEmpty {
      let savedImages = item.getAllQuestionImages().compactMap { $0 }
      if !savedImages.isEmpty && !item.answerTexts.isEmpty {
        allCroppedSets = [savedImages]
        allRecognized = [item.answerTexts]
        allConfidences = [item.confidenceScores]
      }
    }

    // UI配列に反映（空でなければ上書き）
    if !allCroppedSets.isEmpty {
      croppedImageSets = allCroppedSets
      recognizedTextsSets = allRecognized
      confidenceScoreSets = allConfidences

      // ViewModelの2D信頼度も最新のScanResultから復元（PreviewFullScreenViewでの表示用）
      if let latestScan = item.scanResults.max(by: { $0.timestamp < $1.timestamp }),
        !latestScan.confidenceScores2D.isEmpty
      {
        confidenceScores2D = latestScan.confidenceScores2D
      }

      // 代表画像を先頭の最初の画像にする
      if let firstImg = allCroppedSets.first?.first {
        capturedImages = [firstImg]
      }
    }
  }

  /// サンプル画像を読み込んで処理する
  func loadSampleImage() {
    guard !isProcessingSample else { return }

    let loadedSample = UIImage(named: "form", in: Bundle.main, compatibleWith: nil)
    if let sample = loadedSample {
      isProcessingSample = true
      processCapturedImage(sample) {
        self.isProcessingSample = false
      }
    }
  }

  /// プレビューを開始する
  func startPreview(with index: Int) {
    previewIndex = max(0, index)
    // プレビューを表示する前にカメラを確実に停止してセッションを解放する
    pauseAutoCapture()
    scanner.stop()
    isPreviewPresented = true
  }

  /// プレビューを終了する
  func dismissPreview() {
    isPreviewPresented = false
    // プレビューを閉じたらカメラを再開
    resumeAutoCapture()
  }

  /// 指定インデックスのデータセットを削除する
  func deleteDataSet(at index: Int, item: Item?, modelContext: Any?) -> Bool {
    guard index >= 0 && index < croppedImageSets.count else { return false }

    // UI側配列を更新
    croppedImageSets.remove(at: index)
    recognizedTextsSets.remove(at: index)
    confidenceScoreSets.remove(at: index)

    // ItemのscanResultsから対応する ScanResult を削除する
    if let item = item {
      // scanResults の中で、UIで表示している順序は item.scanResults の順序と一致している前提
      // 逆順・タイムスタンプ順などでのズレがある場合は適切なマッピングが必要
      if index >= 0 && index < item.scanResults.count {
        item.scanResults.remove(at: index)
        if let context = modelContext as? ModelContext {
          do {
            try context.save()
          } catch {
            print("データ削除保存エラー: \(error)")
          }
        }
      }
    }

    // previewIndex を調整（削除後に out-of-range にならないように）
    if previewIndex >= croppedImageSets.count {
      previewIndex = max(0, croppedImageSets.count - 1)
    }
    // 削除後に残りがあればモーダルは閉じない（false）、なければ閉じる（true）
    return croppedImageSets.isEmpty
  }

  /// キャプチャされた画像を処理して配列に追加する
  func addCapturedImage(_ image: UIImage, item: Item?, modelContext: Any?) {
    // 画像処理と切り取りはすでにprocessCapturedImageで実行済み
    let croppedImages = lastCroppedImages
    let texts = parsedAnswers

    if croppedImages.isEmpty {
      isCircleDetectionFailed = true
      return
    }

    // 新規スキャンは常に UI に追加して永続化する
    print(
      "CameraViewModel: appending parsedAnswers count=\(texts.count), croppedImages=\(croppedImages.count)"
    )
    capturedImages.append(image)
    croppedImageSets.append(croppedImages)
    recognizedTextsSets.append(texts)
    confidenceScoreSets.append(confidenceScores)

    // スキャン結果をItemに保存（Itemが存在する場合）
    if let item = item {
      saveResultsToItem(
        item,
        croppedImages: croppedImages,
        parsedAnswers: parsedAnswers,
        confidenceScores: confidenceScores
      )

      // SwiftDataで変更を永続化
      if let context = modelContext as? ModelContext {
        do {
          try context.save()
        } catch {
          print("データ保存エラー: \(error)")
        }
      }
    }
  }

  /// パルスアニメーションの状態を管理する
  func updatePulseAnimation(for state: ScanState) {
    if state == .paused {
      withAnimation(Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
        isPulseActive = true
      }
    } else {
      // 状態が変わったらアニメーションフラグをオフにする
      withAnimation(.easeInOut(duration: 0.18)) {
        isPulseActive = false
      }
    }
  }

  /// ViewのonAppear時の処理
  func handleViewAppear(with item: Item?) {
    // 表示時は必要に応じてスキャン再開とデータ復元を行う
    loadExistingData(for: item)
    // resumeAutoCapture は scanner.start() を呼ぶため、
    // ここでカメラを確実に再開できる
    resumeAutoCapture()
    if scanState == .paused {
      updatePulseAnimation(for: .paused)
    }
  }

  /// ViewのonDisappear時の処理
  func handleViewDisappear() {
    // 画面を離れる（ContentView に戻る等）のタイミングで自動キャプチャを停止し、
    // セッション自体も停止してカメラを解放する
    pauseAutoCapture()
    scanner.stop()
    // アニメーションフラグをオフ
    withAnimation(.easeInOut(duration: 0.18)) {
      isPulseActive = false
    }
  }
}

extension CameraViewModel: DocumentScannerDelegate {
  func didCapture(image: UIImage) {
    // 共通処理
    self.processCapturedImage(image)
  }

  func didRecognize(feature: RectangleFeature?, in image: CIImage) {
    DispatchQueue.main.async {
      self.detectedFeature = feature
    }
  }
}

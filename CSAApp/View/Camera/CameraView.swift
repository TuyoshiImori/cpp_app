import Foundation
import SwiftData
import SwiftUI
import UIKit
import Vision

// iOS 向けの CameraView 実装（UIKit を利用）
public struct CameraView: View {
  @StateObject private var viewModel: CameraViewModel
  @Binding public var image: UIImage?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var capturedImages: [UIImage] = []
  @State private var croppedImageSets: [[UIImage]] = []  // 各キャプチャごとの切り取り画像セット
  @State private var isPreviewPresented: Bool = false
  @State private var previewIndex: Int = 0
  @State private var recognizedTexts: [[String]] = []  // 各画像ごとの認識された文字列
  @State private var confidenceScoreSets: [[Float]] = []  // 各キャプチャごとの信頼度スコアセット
  @State private var isCircleDetectionFailed: Bool = false
  @State private var isProcessingSample: Bool = false
  @State private var isPulseActive: Bool = false

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

  public var body: some View {
    ZStack {
      CameraPreview(
        scanner: viewModel.scanner,
        recognizedFeature: $viewModel.detectedFeature,
        previewColor: .constant(viewModel.isAutoCaptureEnabled ? .blue : .clear)
      )
      .edgesIgnoringSafeArea(.all)

      // (上部バーは削除) NavigationStack 側のナビゲーションバーを使う

      // 左下に代表サムネイルを1つだけ表示する（最新のスキャン）
      VStack {
        Spacer()
        HStack {
          if let latestThumb = croppedImageSets.last?.first {
            Button(action: {
              // 最新セットをプレビューする
              previewIndex = max(0, croppedImageSets.count - 1)
              // プレビューを表示する前にカメラを確実に停止してセッションを解放する
              viewModel.pauseAutoCapture()
              viewModel.scanner.stop()
              isPreviewPresented = true
            }) {
              Image(uiImage: latestThumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2))
            }
            .padding(.leading, 8 + safeAreaInsets.left)
            .padding(.bottom, 16 + safeAreaInsets.bottom)
          } else {
            // サムネイルが無い場合は空スペースで場所を確保
            Rectangle()
              .fill(Color.clear)
              .frame(width: 56, height: 56)
              .padding(.leading, 8 + safeAreaInsets.left)
              .padding(.bottom, 16 + safeAreaInsets.bottom)
          }

          Spacer()
        }
      }
      .edgesIgnoringSafeArea(.bottom)

      // 右下 カメラのステータス表示
      VStack {
        Spacer()
        HStack {
          Spacer()
          // .possible / .scanning のときはラベル表示にする。
          Group {
            switch viewModel.scanState {
            case .possible:
              Text("スキャン可能")
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.9))
                .cornerRadius(24)
                .allowsHitTesting(false)  // タップを無効化

            case .scanning:
              HStack(spacing: 10) {
                Text("スキャン中")
                  .font(.headline)
                  .foregroundColor(.black)
                ProgressView()  // インジケーター
                  .progressViewStyle(CircularProgressViewStyle(tint: .black))
                  .scaleEffect(0.8)
                  .frame(width: 16, height: 16)
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 12)
              .background(Color.white.opacity(0.9))
              .cornerRadius(24)
              .allowsHitTesting(false)  // タップを無効化

            case .paused:
              Button(action: {
                viewModel.resumeAutoCapture()
              }) {
                Text("スキャン再開")
                  .font(.headline)
                  .foregroundColor(.black)
                  .padding(.horizontal, 24)
                  .padding(.vertical, 12)
                  .background(Color.white.opacity(0.9))
                  .cornerRadius(24)
              }
              // パルスアニメーション
              .scaleEffect(isPulseActive ? 1.12 : 1.0)
              .opacity(isPulseActive ? 1.0 : 0.90)
              .shadow(
                color: Color.black.opacity(isPulseActive ? 0.28 : 0.06),
                radius: isPulseActive ? 12 : 3, x: 0, y: 3
              )
              .animation(
                .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isPulseActive)
            }
          }
          .padding(.bottom, 24 + safeAreaInsets.bottom)
          .padding(.trailing, 16 + safeAreaInsets.right)
        }
      }
      .edgesIgnoringSafeArea(.bottom)

      // サンプル読み込みボタンは下中央に配置
      VStack {
        Spacer()
        HStack {
          Spacer()
          Button(action: {
            let loadedSample = UIImage(named: "form", in: Bundle.main, compatibleWith: nil)
            if let sample = loadedSample {
              isProcessingSample = true
              viewModel.processCapturedImage(sample) {
                isProcessingSample = false
              }
            }
          }) {
            HStack(spacing: 8) {
              if isProcessingSample {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .frame(width: 20, height: 20)
              } else {
                Image(systemName: "photo.on.rectangle")
              }
              Text(isProcessingSample ? "読み込み中..." : "サンプル読み込み")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.9))
            .cornerRadius(20)
            .shadow(radius: 6)
          }
          .disabled(isProcessingSample)
          Spacer()
        }
        .padding(.bottom, 12 + safeAreaInsets.bottom)
      }

      .alert(isPresented: $isCircleDetectionFailed) {
        Alert(
          title: Text("スキャン失敗"),
          message: Text("適切なフォーマットのアンケートをスキャンしてください。"),
          dismissButton: .default(Text("OK"))
        )
      }
    }
    // View の表示/非表示のライフサイクルでカメラを簡潔に制御する
    .onAppear {
      // 表示時は必要に応じてスキャン再開とデータ復元を行う
      loadExistingData()
      // resumeAutoCapture は scanner.start() を呼ぶため、
      // ここでカメラを確実に再開できる
      viewModel.resumeAutoCapture()
      if viewModel.scanState == .paused {
        withAnimation(Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
          isPulseActive = true
        }
      }
    }
    .onDisappear {
      // 画面を離れる（ContentView に戻る等）のタイミングで自動キャプチャを停止し、
      // セッション自体も停止してカメラを解放する
      viewModel.pauseAutoCapture()
      viewModel.scanner.stop()
      // アニメーションフラグをオフ
      withAnimation(.easeInOut(duration: 0.18)) {
        isPulseActive = false
      }
    }
    .onChange(of: viewModel.scanState) { newState in
      if newState == .paused {
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
    .fullScreenCover(
      isPresented: $isPreviewPresented,
      onDismiss: {
        // プレビューを閉じたらカメラを再開
        viewModel.resumeAutoCapture()
      }
    ) {
      // PreviewFullScreenView は複数の解析セットを受け取るため、recognizedTexts は既に [[String]] なのでそのまま渡す。
      PreviewFullScreenView(
        isPreviewPresented: $isPreviewPresented,
        previewIndex: $previewIndex,
        croppedImageSets: croppedImageSets,
        parsedAnswersSets: recognizedTexts,
        item: item,
        viewModel: viewModel,
        confidenceScores: confidenceScoreSets,
        onDelete: { index in
          // UI配列と永続化された scanResults の両方から指定インデックスのセットを削除する
          guard index >= 0 && index < croppedImageSets.count else { return }

          // UI側配列を更新
          croppedImageSets.remove(at: index)
          recognizedTexts.remove(at: index)
          confidenceScoreSets.remove(at: index)

          // ItemのscanResultsから対応する ScanResult を削除する
          if let item = item {
            // scanResults の中で、UIで表示している順序は item.scanResults の順序と一致している前提
            // 逆順・タイムスタンプ順などでのズレがある場合は適切なマッピングが必要
            if index >= 0 && index < item.scanResults.count {
              item.scanResults.remove(at: index)
              do {
                try modelContext.save()
              } catch {
                print("データ削除保存エラー: \(error)")
              }
            }
          }

          // previewIndex を調整（削除後に out-of-range にならないように）
          if previewIndex >= croppedImageSets.count {
            previewIndex = max(0, croppedImageSets.count - 1)
          }
        }
      )
    }
    .onReceive(viewModel.$capturedImage.compactMap { $0 }) { (img: UIImage) in
      // ViewModel が既に画像処理と切り取りを実行しているため、
      // ここでは ViewModel が保持する結果を利用して UI を更新する
      let croppedImages = viewModel.lastCroppedImages
      // 生のrecognizedTextsの代わりに、parsedAnswers（質問ごとに解析された結果）を使用してください。
      // recognizeTextsにはページ全体のOCR結果が含まれる場合があり、正しく表示されないことがあります。
      let texts = viewModel.parsedAnswers
      if croppedImages.isEmpty {
        isCircleDetectionFailed = true
        return
      }

      // 新規スキャンは常に UI に追加して永続化する
      // （過去の二重追加はサンプル完了側の保存を削除して対処済み）
      print(
        "CameraView: appending parsedAnswers count=\(texts.count), croppedImages=\(croppedImages.count)"
      )
      capturedImages.append(img)
      croppedImageSets.append(croppedImages)
      recognizedTexts.append(texts)
      confidenceScoreSets.append(viewModel.confidenceScores)  // 信頼度スコアも保存
      image = img

      // スキャン結果をItemに保存（Itemが存在する場合）
      if let item = item {
        viewModel.saveResultsToItem(
          item,
          croppedImages: croppedImages,
          parsedAnswers: viewModel.parsedAnswers,
          confidenceScores: viewModel.confidenceScores
        )

        // SwiftDataで変更を永続化
        do {
          try modelContext.save()
        } catch {
          print("データ保存エラー: \(error)")
        }
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

  /// 保存されたスキャンデータを復元してUIに表示する
  private func loadExistingData() {
    guard let item = item else { return }
    // 既存のUI配列をクリアしてから復元する（重複追加防止）
    croppedImageSets = []
    recognizedTexts = []
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
      recognizedTexts = allRecognized
      confidenceScoreSets = allConfidences

      // ViewModelの2D信頼度も最新のScanResultから復元（PreviewFullScreenViewでの表示用）
      if let latestScan = item.scanResults.max(by: { $0.timestamp < $1.timestamp }),
        !latestScan.confidenceScores2D.isEmpty
      {
        viewModel.confidenceScores2D = latestScan.confidenceScores2D
      }

      // 代表画像を先頭の最初の画像にする
      if let firstImg = allCroppedSets.first?.first {
        capturedImages = [firstImg]
        image = firstImg
      }
    }
  }
}

// MARK: - Helpers
extension CameraView {
  /// ネイティブから返された回答文字列を配列に変換する。
  /// - 優先: JSON 配列 (例: ["A","B,C","その他"]) をデコード
  /// - 代替: カンマ区切りで分割 (従来互換)
  fileprivate func decodeAnswerList(from raw: String) -> [String] {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    // JSON array の形をしているかを簡易判定
    if trimmed.first == "[" && trimmed.last == "]" {
      if let data = trimmed.data(using: .utf8) {
        do {
          let arr = try JSONDecoder().decode([String].self, from: data)
          return arr
        } catch {
          // JSON デコード失敗 -> フォールバックへ
          print("CameraView.decodeAnswerList: JSON decode failed: \(error)")
        }
      }
    }
    // フォールバック: カンマで分割（従来互換）
    return raw.components(separatedBy: ",")
  }
}

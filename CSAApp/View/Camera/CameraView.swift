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
  @Environment(\.colorScheme) private var colorScheme

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

      // ViewModel が処理中フラグを出しているときは全画面のローディングオーバーレイを表示
      if viewModel.isProcessing {
        Color.black.opacity(0.45)
          .edgesIgnoringSafeArea(.all)

        VStack(spacing: 12) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
            .scaleEffect(1.5)
          Text("スキャン中...")
            .foregroundColor(.white)
            .font(.headline)
        }
        .padding(24)
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
      }

      // (上部バーは削除) NavigationStack 側のナビゲーションバーを使う

      // 左下に代表サムネイルを1つだけ表示する（最新のスキャン）
      VStack {
        Spacer()
        HStack {
          if let latestThumb = viewModel.croppedImageSets.last?.first {
            Button(action: {
              // 最新セットをプレビューする
              viewModel.startPreview(with: max(0, viewModel.croppedImageSets.count - 1))
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
                .foregroundColor(ButtonForeground.color(for: colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .allowsHitTesting(false)  // タップを無効化
                .glassEffect()

            case .scanning:
              HStack(spacing: 10) {
                Text("スキャン中")
                  .font(.headline)
                  .foregroundColor(ButtonForeground.color(for: colorScheme))
                ProgressView()  // インジケーター
                  .progressViewStyle(
                    CircularProgressViewStyle(tint: ButtonForeground.color(for: colorScheme))
                  )
                  .scaleEffect(0.8)
                  .frame(width: 16, height: 16)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .allowsHitTesting(false)  // タップを無効化
              .glassEffect()

            case .paused:
              Button(action: {
                viewModel.resumeAutoCapture()
              }) {
                Text("スキャン再開")
                  .font(.headline)
                  .foregroundColor(ButtonForeground.color(for: colorScheme))
                  .padding(.horizontal, 16)
                  .padding(.vertical, 10)
              }
              // パルスアニメーション
              .scaleEffect(viewModel.isPulseActive ? 1.12 : 1.0)
              .opacity(viewModel.isPulseActive ? 1.0 : 0.90)
              .shadow(
                color: Color.black.opacity(viewModel.isPulseActive ? 0.28 : 0.06),
                radius: viewModel.isPulseActive ? 12 : 3, x: 0, y: 3
              )
              .animation(
                .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                value: viewModel.isPulseActive
              )
              .glassEffect(.regular.interactive())
            }
          }
          .padding(.bottom, 24 + safeAreaInsets.bottom)
          .padding(.trailing, 16 + safeAreaInsets.right)
        }
      }
      .edgesIgnoringSafeArea(.bottom)

      // サンプル読み込みボタンは下中央に配置
      // VStack {
      //   Spacer()
      //   HStack {
      //     Spacer()
      //     Button(action: {
      //       viewModel.loadSampleImage()
      //     }) {
      //       HStack(spacing: 8) {
      //         if viewModel.isProcessingSample {
      //           ProgressView()
      //             .progressViewStyle(CircularProgressViewStyle(tint: .white))
      //             .frame(width: 20, height: 20)
      //         } else {
      //           Image(systemName: "photo.on.rectangle")
      //         }
      //         Text(viewModel.isProcessingSample ? "読み込み中..." : "サンプル読み込み")
      //       }
      //       .font(.headline)
      //       .foregroundColor(.white)
      //       .padding(.horizontal, 16)
      //       .padding(.vertical, 12)
      //       .background(Color.blue.opacity(0.9))
      //       .cornerRadius(20)
      //       .shadow(radius: 6)
      //     }
      //     .disabled(viewModel.isProcessingSample)
      //     Spacer()
      //   }
      //   .padding(.bottom, 12 + safeAreaInsets.bottom)
      // }

      .alert(isPresented: $viewModel.isCircleDetectionFailed) {
        Alert(
          title: Text("スキャン失敗"),
          message: Text("適切なフォーマットのアンケートをスキャンしてください。"),
          dismissButton: .default(Text("OK"))
        )
      }
    }
    // View の表示/非表示のライフサイクルでカメラを簡潔に制御する
    .onAppear {
      viewModel.handleViewAppear(with: item)
    }
    .onDisappear {
      viewModel.handleViewDisappear()
    }
    .onChange(of: viewModel.scanState) { newState in
      viewModel.updatePulseAnimation(for: newState)
    }
    .fullScreenCover(
      isPresented: $viewModel.isPreviewPresented,
      onDismiss: {
        viewModel.dismissPreview()
      }
    ) {
      // PreviewFullScreenView は複数の解析セットを受け取るため、recognizedTexts は既に [[String]] なのでそのまま渡す。
      PreviewFullScreenView(
        isPreviewPresented: $viewModel.isPreviewPresented,
        previewIndex: $viewModel.previewIndex,
        croppedImageSets: viewModel.croppedImageSets,
        parsedAnswersSets: viewModel.recognizedTextsSets,
        item: item,
        viewModel: viewModel,
        confidenceScores: viewModel.confidenceScoreSets,
        onDelete: { index in
          return viewModel.deleteDataSet(at: index, item: item, modelContext: modelContext)
        }
      )
    }
    .onReceive(viewModel.$capturedImage.compactMap { $0 }) { (img: UIImage) in
      // ViewModelが処理した画像をViewに反映
      viewModel.addCapturedImage(img, item: item, modelContext: modelContext)
      image = img
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

import Foundation
import SwiftData
import SwiftUI
import Vision

#if canImport(UIKit)
  import UIKit
#endif

/// プレビュー全画面表示用のコンポーネント
/// CameraViewから切り出して、信頼度表示機能も追加
struct PreviewFullScreenView: View {
  // MARK: - Properties
  @Binding var isPreviewPresented: Bool
  @Binding var previewIndex: Int

  let croppedImageSets: [[UIImage]]
  let parsedAnswersSets: [[String]]
  // ViewModel を注入してフォーマット関数を利用できるようにする
  var viewModel: CameraViewModel? = nil
  // 分析画面に渡すItem
  let item: Item?
  // プレビュー中のセットが削除されたときに呼ばれるクロージャ
  // 戻り値は「モーダルを閉じるべきか」を示す Bool
  var onDelete: ((Int) -> Bool)? = nil

  // 信頼度情報を格納するための配列（将来の実装用）
  let confidenceScores: [[Float]]?

  // 分析画面の表示状態
  // isAnalysisActive は ViewModel に移譲している

  // MARK: - Init
  init(
    isPreviewPresented: Binding<Bool>,
    previewIndex: Binding<Int>,
    croppedImageSets: [[UIImage]],
    parsedAnswersSets: [[String]],
    // 分析画面に渡すItemを追加
    item: Item? = nil,
    viewModel: CameraViewModel? = nil,
    confidenceScores: [[Float]]? = nil,
    onDelete: ((Int) -> Bool)? = nil
  ) {
    self._isPreviewPresented = isPreviewPresented
    self._previewIndex = previewIndex
    self.croppedImageSets = croppedImageSets
    self.parsedAnswersSets = parsedAnswersSets
    self.item = item
    self.viewModel = viewModel
    self.confidenceScores = confidenceScores
    self.onDelete = onDelete
  }

  // MARK: - Body
  @Environment(\.colorScheme) private var colorScheme

  private var previewCardBackground: Color {
    if colorScheme == .dark {
      return Color(white: 0.09)
    } else {
      #if canImport(UIKit)
        return Color(UIColor.systemBackground)
      #else
        return Color.white
      #endif
    }
  }

  private var previewScreenBackground: some View {
    Group {
      if colorScheme == .dark {
        Color.black.ignoresSafeArea()
      } else {
        #if canImport(UIKit)
          Color(UIColor.systemGray6).ignoresSafeArea()
        #else
          Color(.init(white: 0.95, alpha: 1.0)).ignoresSafeArea()
        #endif
      }
    }
  }

  var body: some View {
    // 転送された UI は `PreviewFullScreenContentView` に委譲
    NavigationStack {
      PreviewFullScreenContentView(
        isPreviewPresented: $isPreviewPresented,
        previewIndex: $previewIndex,
        croppedImageSets: croppedImageSets,
        parsedAnswersSets: parsedAnswersSets,
        viewModel: viewModel,
        item: item,
        onDelete: onDelete,
        confidenceScores: confidenceScores
      )
    }
  }

  // 画像表示部分は `PreviewFullScreenContentView` に移譲済み

  // MARK: - Helper Methods

  /// 信頼度に応じた色を返す
  private func confidenceColor(for confidence: Float) -> Color {
    switch confidence {
    case 80...:
      return .green  // 80%以上は緑色
    case 60..<80:
      return .yellow  // 60-80%は黄色
    case 40..<60:
      return .orange  // 40-60%はオレンジ色
    default:
      return .red  // 40%未満は赤色
    }
  }

  // (複雑な helper は削除。情報は上で表示済み)
}

// MARK: - Preview
#if canImport(UIKit)
  struct PreviewFullScreenView_Previews: PreviewProvider {
    @State static var isPresented = true
    @State static var previewIndex = 0

    static var previews: some View {
      // プレビューでは実際の画像は不要なので空配列で簡素化
      PreviewFullScreenView(
        isPreviewPresented: $isPresented,
        previewIndex: $previewIndex,
        croppedImageSets: [],
        parsedAnswersSets: [],
        item: nil
      )
    }
  }
#endif

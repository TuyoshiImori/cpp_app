import Foundation
import SwiftUI
import Vision

#if canImport(UIKit)
  import UIKit
#endif

/// 分割されたプレビュー全画面表示用の本体ビュー
struct PreviewFullScreenContentView: View {
  @Binding var isPreviewPresented: Bool
  @Binding var previewIndex: Int

  let croppedImageSets: [[UIImage]]
  let parsedAnswersSets: [[String]]
  var viewModel: CameraViewModel? = nil
  let item: Item?
  var onDelete: ((Int) -> Bool)? = nil

  // 信頼度情報を格納するための配列（将来の実装用）
  let confidenceScores: [[Float]]?

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext

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
    ZStack {
      previewScreenBackground

      if !croppedImageSets.isEmpty {
        PreviewFullScreenImagesTabView(
          previewIndex: $previewIndex, croppedImageSets: croppedImageSets,
          parsedAnswersSets: parsedAnswersSets, viewModel: viewModel,
          confidenceScores: confidenceScores)
      }

      VStack {
        HStack {
          Button(action: { isPreviewPresented = false }) {
            Label("閉じる", systemImage: "xmark")
              .labelStyle(.iconOnly)
              .font(.system(size: 20))
              .padding(.horizontal, 12)
              .padding(.vertical, 12)
              #if canImport(UIKit)
                .foregroundColor(Color(UIColor.label))
              #else
                .foregroundColor(.primary)
              #endif
          }
          .glassEffect(.regular.interactive())

          Spacer()

          if item != nil {
            Button(action: {
              if let vm = viewModel {
                vm.isAnalysisActive = true
              }
            }) {
              HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                  .font(.system(size: 20))
                Text("分析")
                  .font(.headline)
              }
              #if canImport(UIKit)
                .foregroundColor(Color(UIColor.label))
              #else
                .foregroundColor(.primary)
              #endif
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
            }
            .glassEffect(.regular.interactive())
          }
        }
        .padding(.horizontal, 20)
        Spacer()
      }

      if let it = item {
        NavigationLink(
          destination: AnalysisView(
            item: it,
            allCroppedImageSets: croppedImageSets,
            allParsedAnswersSets: parsedAnswersSets,
            allConfidenceScores: confidenceScores
          ),
          isActive: bindingForAnalysisActive()
        ) {
          EmptyView()
        }
        .hidden()
      }

      VStack {
        Spacer()
        HStack {
          Spacer()
          PreviewFullScreenDeleteButtonView(
            previewIndex: $previewIndex,
            croppedImageSets: croppedImageSets,
            parsedAnswersSets: parsedAnswersSets,
            item: item,
            viewModel: viewModel,
            isPreviewPresented: $isPreviewPresented,
            onDelete: onDelete
          )
        }
        .padding(.bottom, 30)
        .padding(.trailing, 20)
      }
    }
  }

  // MARK: - Helpers
  private func bindingForAnalysisActive() -> Binding<Bool> {
    if let vm = viewModel {
      return Binding(get: { vm.isAnalysisActive }, set: { vm.isAnalysisActive = $0 })
    } else {
      return .constant(false)
    }
  }

  /// 信頼度に応じた色を返す
  private func confidenceColor(for confidence: Float) -> Color {
    switch confidence {
    case 80...:
      return .green
    case 60..<80:
      return .yellow
    case 40..<60:
      return .orange
    default:
      return .red
    }
  }
}

#if canImport(UIKit)
  struct PreviewFullScreenContentView_Previews: PreviewProvider {
    @State static var isPresented = true
    @State static var previewIndex = 0

    static var previews: some View {
      PreviewFullScreenContentView(
        isPreviewPresented: $isPresented,
        previewIndex: $previewIndex,
        croppedImageSets: [],
        parsedAnswersSets: [],
        viewModel: nil,
        item: nil,
        onDelete: nil,
        confidenceScores: nil
      )
    }
  }
#endif

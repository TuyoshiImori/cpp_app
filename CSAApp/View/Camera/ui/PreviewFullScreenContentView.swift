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
        imagesTab()
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
              // ViewModel が提供されていればそれを更新、なければローカルで処理
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

      // NavigationLink for analysis
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
          DeleteButtonView(
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
      // Fallback: closed binding (unused if no vm provided)
      return .constant(false)
    }
  }

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

  // MARK: - Delete Button Subview
  private struct DeleteButtonView: View {
    @Binding var previewIndex: Int
    let croppedImageSets: [[UIImage]]
    let parsedAnswersSets: [[String]]
    let item: Item?
    var viewModel: CameraViewModel?
    @Binding var isPreviewPresented: Bool
    var onDelete: ((Int) -> Bool)?

    @Environment(\.modelContext) private var modelContext
    @State private var showConfirm = false

    var body: some View {
      Button(role: .destructive) {
        showConfirm = true
      } label: {
        HStack {
          Image(systemName: "trash")
          Text("削除")
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
      .glassEffect(.regular.tint(Color.red.opacity(0.7)).interactive())
      .confirmationDialog("この回答を削除しますか？", isPresented: $showConfirm, titleVisibility: .visible) {
        Button("削除", role: .destructive) {
          var shouldClose = true
          if let callback = onDelete {
            shouldClose = callback(previewIndex)
          } else if let vm = viewModel {
            // use ViewModel's deleteDataSet to perform deletion and persistence
            shouldClose = vm.deleteDataSet(at: previewIndex, item: item, modelContext: modelContext)
          } else if let it = item {
            // Fallback: delete whole item
            modelContext.delete(it)
            shouldClose = true
          }

          if shouldClose {
            isPreviewPresented = false
          }
        }
        Button("キャンセル", role: .cancel) {}
      }
    }
  }

  // MARK: - Images Tab
  @ViewBuilder
  private func imagesTab() -> some View {
    TabView(selection: $previewIndex) {
      ForEach(0..<croppedImageSets.count, id: \.self) { setIdx in
        let imageSet = croppedImageSets[setIdx]
        GeometryReader { geo in
          ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
              ForEach(0..<imageSet.count, id: \.self) { imgIdx in
                let img = imageSet[imgIdx]
                VStack {
                  Text("設問 \(imgIdx + 1)")
                    .foregroundColor(.primary)
                    .font(.headline)
                    .padding(.top, 10)

                  Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: geo.size.width - 20)
                    .padding(.horizontal, 10)

                  if setIdx < parsedAnswersSets.count, imgIdx < parsedAnswersSets[setIdx].count {
                    let answerIndex = parsedAnswersSets[setIdx][imgIdx]

                    VStack(alignment: .leading, spacing: 4) {
                      Text("検出結果:")
                        .foregroundColor(.primary)
                        .font(.subheadline)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                      let shouldShowOverallConfidence = !answerIndex.contains("\n")

                      if shouldShowOverallConfidence {
                        if let confidenceScores = confidenceScores,
                          setIdx < confidenceScores.count,
                          imgIdx < confidenceScores[setIdx].count
                        {
                          let confidence = confidenceScores[setIdx][imgIdx]
                          HStack {
                            Text("信頼度:")
                              .foregroundColor(.secondary)
                              .font(.caption)
                            Text("\(String(format: "%.1f", confidence))%")
                              .foregroundColor(confidenceColor(for: confidence))
                              .font(.caption)
                              .bold()
                          }
                        } else {
                          HStack {
                            Text("信頼度:")
                              .foregroundColor(.secondary)
                              .font(.caption)
                            Text("信頼度なし")
                              .foregroundColor(.secondary)
                              .font(.caption)
                              .italic()
                          }
                        }
                      }

                      if let qtypes = viewModel?.initialQuestionTypes, imgIdx < qtypes.count {
                        switch qtypes[imgIdx] {
                        case .info(_, _):
                          let lines =
                            viewModel?.formattedInfoLines(for: imgIdx, parsedAnswer: answerIndex)
                            ?? []
                          ForEach(lines.indices, id: \.self) { idx in
                            Text(lines[idx])
                              .foregroundColor(.primary)
                              .font(.subheadline)
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .multilineTextAlignment(.leading)
                              .fixedSize(horizontal: false, vertical: true)
                              .padding(.vertical, 2)
                          }
                        default:
                          if answerIndex == "-1" {
                            Text("回答: 未検出")
                              .foregroundColor(.orange)
                              .font(.subheadline)
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .multilineTextAlignment(.leading)
                          } else if !answerIndex.isEmpty {
                            Text("回答: \(answerIndex)")
                              .foregroundColor(.green)
                              .font(.subheadline)
                              .bold()
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .multilineTextAlignment(.leading)
                          } else {
                            Text("回答: 検出エラー")
                              .foregroundColor(.red)
                              .font(.subheadline)
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .multilineTextAlignment(.leading)
                          }
                        }
                      } else {
                        Text("設問情報なし")
                          .foregroundColor(.secondary)
                          .font(.subheadline)
                      }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                  }
                }
                .padding()
                .background(previewCardBackground)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                .padding(.horizontal, 14)
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

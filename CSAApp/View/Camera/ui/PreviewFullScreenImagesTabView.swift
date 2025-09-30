import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// 画像の Tab 表示を担当する独立 View
struct PreviewFullScreenImagesTabView: View {
  @Binding var previewIndex: Int
  let croppedImageSets: [[UIImage]]
  let parsedAnswersSets: [[String]]
  var viewModel: CameraViewModel?
  let confidenceScores: [[Float]]?

  @Environment(\.colorScheme) private var colorScheme

  init(
    previewIndex: Binding<Int>, croppedImageSets: [[UIImage]] = [],
    parsedAnswersSets: [[String]] = [], viewModel: CameraViewModel? = nil,
    confidenceScores: [[Float]]? = nil
  ) {
    self._previewIndex = previewIndex
    self.croppedImageSets = croppedImageSets
    self.parsedAnswersSets = parsedAnswersSets
    self.viewModel = viewModel
    self.confidenceScores = confidenceScores
  }

  var body: some View {
    TabView(selection: $previewIndex) {
      ForEach(0..<croppedImageSets.count, id: \.self) { setIdx in
        let imageSet = croppedImageSets[setIdx]
        GeometryReader { geo in
          ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
              ForEach(0..<imageSet.count, id: \.self) { imgIdx in
                let img = imageSet[imgIdx]
                VStack {
                  // 設問ヘッダーを分析画面のカードに合わせる
                  HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "dot.circle")
                      .foregroundColor(.blue)
                      .font(.title2)

                    VStack(alignment: .leading, spacing: 6) {
                      Text("設問 \(imgIdx + 1)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    }
                    Spacer()
                  }
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

                      // 信頼度表示は UI から削除（データは引き続き viewModel に残す）

                      if let qtypes = viewModel?.initialQuestionTypes, imgIdx < qtypes.count {
                        switch qtypes[imgIdx] {
                        case .info(_, _):
                          let lines =
                            viewModel?.formattedInfoLines(for: imgIdx, parsedAnswer: answerIndex)
                            ?? []
                          ForEach(lines.indices, id: \.self) { idx in
                            Text(lines[idx])
                              .foregroundColor(.green)
                              .font(.subheadline)
                              .bold()
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .multilineTextAlignment(.leading)
                              .fixedSize(horizontal: false, vertical: true)
                              .padding(.vertical, 2)
                          }
                        default:
                          if answerIndex == "-1" {
                            Text("未検出")
                              .foregroundColor(.orange)
                              .font(.subheadline)
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .multilineTextAlignment(.leading)
                          } else if !answerIndex.isEmpty {
                            Text(answerIndex)
                              .foregroundColor(.primary)
                              .font(.subheadline)
                              .bold()
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .multilineTextAlignment(.leading)
                          } else {
                            Text("検出エラー")
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
                // 共通のカード背景ユーティリティを利用
                .background(CardBackground.color(for: colorScheme))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                .padding(.horizontal, 14)
              }
            }
            .padding(.top, 50)
            // 下部に余白を追加して、ページインジケータや端末のホームバーと被らないようにする
            .padding(.bottom, 80)
          }
        }
        .tag(setIdx)
      }
    }
    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
  }

  private func confidenceColor(for confidence: Float) -> Color {
    switch confidence {
    case 80...: return .green
    case 60..<80: return .yellow
    case 40..<60: return .orange
    default: return .red
    }
  }
}

struct PreviewFullScreenImagesTabView_Previews: PreviewProvider {
  @State static var idx = 0
  static var previews: some View {
    PreviewFullScreenImagesTabView(previewIndex: $idx)
  }
}

import SwiftUI
import Vision

/// プレビュー全画面表示用のコンポーネント
/// CameraViewから切り出して、信頼度表示機能も追加
struct PreviewFullScreenView: View {
  // MARK: - Properties
  @Binding var isPreviewPresented: Bool
  @Binding var previewIndex: Int

  let croppedImageSets: [[UIImage]]
  let parsedAnswers: [String]
  let item: Item?

  // 信頼度情報を格納するための配列（将来の実装用）
  let confidenceScores: [[Float]]?

  // MARK: - Init
  init(
    isPreviewPresented: Binding<Bool>,
    previewIndex: Binding<Int>,
    croppedImageSets: [[UIImage]],
    parsedAnswers: [String],
    item: Item?,
    confidenceScores: [[Float]]? = nil
  ) {
    self._isPreviewPresented = isPreviewPresented
    self._previewIndex = previewIndex
    self.croppedImageSets = croppedImageSets
    self.parsedAnswers = parsedAnswers
    self.item = item
    self.confidenceScores = confidenceScores
  }

  // MARK: - Body
  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()

      if !croppedImageSets.isEmpty {
        TabView(selection: $previewIndex) {
          ForEach(Array(croppedImageSets.enumerated()), id: \.offset) { setIdx, imageSet in
            GeometryReader { geo in
              ScrollView(.vertical) {
                VStack(spacing: 10) {
                  ForEach(Array(imageSet.enumerated()), id: \.offset) { imgIdx, img in
                    VStack {
                      Text("設問 \(imgIdx + 1)")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.top, 10)

                      Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width - 20)
                        .padding(.horizontal, 10)

                      // 検出結果と信頼度を表示
                      if imgIdx < parsedAnswers.count {
                        let answerIndex = parsedAnswers[imgIdx]

                        VStack(alignment: .leading, spacing: 4) {
                          Text("検出結果:")
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .bold()

                          // 信頼度表示（もし利用可能なら）
                          if let confidenceScores = confidenceScores,
                            setIdx < confidenceScores.count,
                            imgIdx < confidenceScores[setIdx].count
                          {
                            let confidence = confidenceScores[setIdx][imgIdx]
                            HStack {
                              Text("信頼度:")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                              Text("\(String(format: "%.1f", confidence))%")
                                .foregroundColor(confidenceColor(for: confidence))
                                .font(.caption)
                                .bold()
                            }
                          }

                          if let item = item, imgIdx < item.questionTypes.count {
                            let questionType = item.questionTypes[imgIdx]
                            displayAnswer(for: questionType, answer: answerIndex)
                          } else {
                            Text("設問情報なし")
                              .foregroundColor(.gray)
                              .font(.subheadline)
                          }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                      }
                    }
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

      // 閉じるボタン
      Button(action: { isPreviewPresented = false }) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 36))
          .foregroundColor(.white)
          .padding()
      }
    }
  }

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

  /// 質問タイプに応じた回答表示
  @ViewBuilder
  private func displayAnswer(for questionType: QuestionType, answer: String) -> some View {
    switch questionType {
    case .single(let question, _):
      Text("設問: \(question)")
        .foregroundColor(.white.opacity(0.8))
        .font(.caption)

      if answer == "-1" {
        Text("回答: 未選択")
          .foregroundColor(.orange)
          .font(.subheadline)
      } else if !answer.isEmpty {
        Text("回答: \(answer)")
          .foregroundColor(.green)
          .font(.subheadline)
          .bold()
      } else {
        Text("回答: 検出エラー")
          .foregroundColor(.red)
          .font(.subheadline)
      }

    case .multiple(let question, _):
      Text("設問: \(question)")
        .foregroundColor(.white.opacity(0.8))
        .font(.caption)

      if answer == "-1" {
        Text("回答: 未選択")
          .foregroundColor(.orange)
          .font(.subheadline)
      } else if !answer.isEmpty {
        Text("回答: \(answer)")
          .foregroundColor(.purple)
          .font(.subheadline)
          .bold()
      } else {
        Text("回答: 検出エラー")
          .foregroundColor(.red)
          .font(.subheadline)
      }

    case .text(let question):
      Text("設問: \(question)")
        .foregroundColor(.white.opacity(0.8))
        .font(.caption)

      if answer == "-1" {
        Text("回答: 未検出")
          .foregroundColor(.orange)
          .font(.subheadline)
      } else if !answer.isEmpty {
        Text("回答: \(answer)")
          .foregroundColor(.blue)
          .font(.subheadline)
          .bold()
      } else {
        Text("回答: 検出エラー")
          .foregroundColor(.red)
          .font(.subheadline)
      }

    case .info(let question, _):
      Text("設問: \(question)")
        .foregroundColor(.white.opacity(0.8))
        .font(.caption)

      if answer == "-1" {
        Text("回答: 未検出")
          .foregroundColor(.orange)
          .font(.subheadline)
      } else if !answer.isEmpty {
        Text("回答: \(answer)")
          .foregroundColor(.purple)
          .font(.subheadline)
          .bold()
      } else {
        Text("回答: 検出エラー")
          .foregroundColor(.red)
          .font(.subheadline)
      }
    }
  }
}

// MARK: - Preview
struct PreviewFullScreenView_Previews: PreviewProvider {
  @State static var isPresented = true
  @State static var previewIndex = 0

  static var previews: some View {
    PreviewFullScreenView(
      isPreviewPresented: $isPresented,
      previewIndex: $previewIndex,
      croppedImageSets: [],
      parsedAnswers: [],
      item: nil,
      confidenceScores: nil
    )
  }
}

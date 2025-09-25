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
  let parsedAnswers: [String]
  // ViewModel を注入してフォーマット関数を利用できるようにする
  var viewModel: CameraViewModel? = nil

  // 信頼度情報を格納するための配列（将来の実装用）
  let confidenceScores: [[Float]]?

  // MARK: - Init
  init(
    isPreviewPresented: Binding<Bool>,
    previewIndex: Binding<Int>,
    croppedImageSets: [[UIImage]],
    parsedAnswers: [String],
    // item パラメータは廃止。必要なら viewModel.initialQuestionTypes を渡す
    viewModel: CameraViewModel? = nil,
    confidenceScores: [[Float]]? = nil
  ) {
    self._isPreviewPresented = isPreviewPresented
    self._previewIndex = previewIndex
    self.croppedImageSets = croppedImageSets
    self.parsedAnswers = parsedAnswers
    self.viewModel = viewModel
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
                VStack(alignment: .leading, spacing: 10) {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)

                          // info 設問は parsedAnswer に改行を含む想定なので、
                          // 改行が含まれる場合は総合的な信頼度表示をスキップする。
                          let shouldShowOverallConfidence = !answerIndex.contains("\n")

                          if shouldShowOverallConfidence {
                            // 信頼度表示（もし利用可能なら）。存在しない場合は「信頼度なし」を表示する
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
                            } else {
                              // 信頼度データが存在しない、またはインデックスが範囲外の場合のフォールバック表示
                              HStack {
                                Text("信頼度:")
                                  .foregroundColor(.white.opacity(0.8))
                                  .font(.caption)
                                Text("信頼度なし")
                                  .foregroundColor(.gray)
                                  .font(.caption)
                                  .italic()
                              }
                            }
                          }

                          // ViewModel の initialQuestionTypes を参照して info タイプか判定
                          if let qtypes = viewModel?.initialQuestionTypes, imgIdx < qtypes.count {
                            // QuestionType の詳細構造をここで直接扱わず、info かどうかのみ判定
                            switch qtypes[imgIdx] {
                            case .info(_, _):
                              let lines =
                                viewModel?.formattedInfoLines(
                                  for: imgIdx, parsedAnswer: answerIndex) ?? []
                              ForEach(lines.indices, id: \.self) { idx in
                                Text(lines[idx])
                                  .foregroundColor(.white)
                                  .font(.subheadline)
                                  .frame(maxWidth: .infinity, alignment: .leading)
                                  .multilineTextAlignment(.leading)
                                  .fixedSize(horizontal: false, vertical: true)
                                  .padding(.vertical, 2)
                              }
                            default:
                              // 非 info の場合は単純に回答表示を行う
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

  // (複雑な helper は削除。情報は上で表示済み)
}

// MARK: - Preview
struct PreviewFullScreenView_Previews: PreviewProvider {
  @State static var isPresented = true
  @State static var previewIndex = 0

  static var previews: some View {
    // プレビューでは実際の画像は不要なので空配列で簡素化
    PreviewFullScreenView(
      isPreviewPresented: $isPresented,
      previewIndex: $previewIndex,
      croppedImageSets: [],
      parsedAnswers: []
    )
  }
}

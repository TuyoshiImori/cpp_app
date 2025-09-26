import Foundation
import SwiftData
import SwiftUI
import UIKit
import Vision

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
  @State private var isAnalysisPresented = false
  // NavigationLink での push 用フラグ
  @State private var isAnalysisActive = false

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
  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()
        if !croppedImageSets.isEmpty {
          imagesTab()
        }

        // 上部のボタンオーバーレイ
        VStack {
          HStack {
            // 左上の閉じるボタン
            Button(action: { isPreviewPresented = false }) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.white)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
            }

            Spacer()

            // 右上の分析ボタン
            if item != nil {
              Button(action: {
                // isActive フラグを立てて NavigationLink を発火させる
                isAnalysisActive = true
              }) {
                HStack(spacing: 8) {
                  Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 20))
                  Text("分析")
                    .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(20)
              }
            }
          }
          .padding(.horizontal, 20)
          Spacer()
        }

        // 背景に非表示の NavigationLink を置いて、isAnalysisActive を true にすることで push する
        if let it = item {
          NavigationLink(
            destination: AnalysisView(
              item: it,
              allCroppedImageSets: croppedImageSets,
              allParsedAnswersSets: parsedAnswersSets,
              allConfidenceScores: confidenceScores
            ),
            isActive: $isAnalysisActive
          ) {
            EmptyView()
          }
          .hidden()
        }

        // 下部の削除ボタンオーバーレイ（右下に寄せる）
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
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.85))
        .cornerRadius(12)
      }
      .confirmationDialog("この回答を削除しますか？", isPresented: $showConfirm, titleVisibility: .visible) {
        Button("削除", role: .destructive) {
          // 削除処理: item 単体削除 or 特定セット削除のコールバック
          var shouldClose = true
          if let callback = onDelete {
            shouldClose = callback(previewIndex)
          } else if let it = item {
            // フォールバック: item を丸ごと削除
            modelContext.delete(it)
            shouldClose = true
          }
          // モーダルを閉じるかどうかはコールバックの戻り値に従う
          if shouldClose {
            isPreviewPresented = false
          }
        }
        Button("キャンセル", role: .cancel) {}
      }
    }
  }

  // MARK: - Subviews
  @ViewBuilder
  private func imagesTab() -> some View {
    // 単一プレビューの TabView を表示（上部のサムネイル一覧は表示しない）
    TabView(selection: $previewIndex) {
      ForEach(0..<croppedImageSets.count, id: \.self) { setIdx in
        let imageSet = croppedImageSets[setIdx]
        GeometryReader { geo in
          ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(0..<imageSet.count, id: \.self) { imgIdx in
                let img = imageSet[imgIdx]
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
                  if setIdx < parsedAnswersSets.count, imgIdx < parsedAnswersSets[setIdx].count {
                    let answerIndex = parsedAnswersSets[setIdx][imgIdx]

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
                            viewModel?.formattedInfoLines(for: imgIdx, parsedAnswer: answerIndex)
                            ?? []
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
      parsedAnswersSets: [],
      item: nil
    )
  }
}

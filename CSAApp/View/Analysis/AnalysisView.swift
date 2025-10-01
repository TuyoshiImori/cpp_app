import SwiftData
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// 分析画面のView
/// Itemのスキャン結果を分析して表示します
struct AnalysisView: View {
  // MARK: - Properties
  @StateObject private var viewModel = AnalysisViewModel()
  @Environment(\.dismiss) private var dismiss

  let item: Item
  // 全ての回答データは ViewModel に渡すため一時的に受け取る（UI 自体にはロジックを持たせない）
  let allCroppedImageSets: [[UIImage]]
  let allParsedAnswersSets: [[String]]
  let allConfidenceScores: [[Float]]?
  // CSV 共有 state
  @State private var isShowingShare: Bool = false
  @State private var exportedFileURL: URL? = nil

  // MARK: - Initializer
  /// 新しいイニシャライザ：全ての回答データを受け取る
  init(
    item: Item,
    allCroppedImageSets: [[UIImage]] = [],
    allParsedAnswersSets: [[String]] = [],
    allConfidenceScores: [[Float]]? = nil
  ) {
    self.item = item
    self.allCroppedImageSets = allCroppedImageSets
    self.allParsedAnswersSets = allParsedAnswersSets
    self.allConfidenceScores = allConfidenceScores
  }

  /// 従来の互換性のためのイニシャライザ
  init(item: Item) {
    self.item = item
    self.allCroppedImageSets = []
    self.allParsedAnswersSets = []
    self.allConfidenceScores = nil
  }

  // MARK: - Body
  @Environment(\.colorScheme) private var colorScheme

  // カードおよび背景の色を動的に決定する
  private var cardBackgroundColor: Color {
    if colorScheme == .dark {
      // ダークモード時は薄い黒のカード背景
      return Color(white: 0.08)
    } else {
      #if canImport(UIKit)
        return Color(UIColor.systemBackground)
      #else
        return Color.white
      #endif
    }
  }

  private var screenBackground: some View {
    Group {
      if colorScheme == .dark {
        Color.black.ignoresSafeArea()
      } else {
        #if canImport(UIKit)
          Color(UIColor.systemGray6).ignoresSafeArea()
        #else
          Color.gray.opacity(0.06).ignoresSafeArea()
        #endif
      }
    }
  }

  var body: some View {
    ZStack {
      // 背景（ダークモードは黒、ライトは薄グレー）
      screenBackground

      if viewModel.isLoading {
        // ローディング表示
        VStack {
          ProgressView()
            .scaleEffect(1.5)
          Text("分析中...")
            .font(.headline)
            .padding(.top)
            .foregroundColor(Color.primary)
        }
      } else {
        // メインコンテンツ
        ScrollView {
          VStack(spacing: 20) {
            // サマリーカード
            summaryCard

            // 設問ごとの分析結果を表示（親側で白カードを付与）
            ForEach(0..<item.questionTypes.count, id: \.self) { questionIndex in
              questionAnalysisCard(for: questionIndex)
                .padding()
                // 設問カードの背景を共通ユーティリティから取得
                .background(CardBackground.color(for: colorScheme))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                .padding(.horizontal, 4)
            }
          }
          .padding()
        }
      }
    }
    .navigationTitle("分析結果")
    .navigationBarTitleDisplayMode(.large)
    .sheet(isPresented: $isShowingShare, onDismiss: { exportedFileURL = nil }) {
      if let url = exportedFileURL {
        ActivityView(activityItems: [url])
      } else {
        EmptyView()
      }
    }
    .onAppear {
      // View が表示されたときに ViewModel に item と外部データを渡す
      viewModel.setItem(
        item, allCroppedImageSets: allCroppedImageSets as [[Any]],
        allParsedAnswersSets: allParsedAnswersSets, allConfidenceScores: allConfidenceScores)
    }
  }

  // MARK: - Summary Card
  private var summaryCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        // VStack(alignment: .leading, spacing: 4) {
        //   Text("全体信頼度")
        //     .font(.caption)
        //     .foregroundColor(.secondary)
        //   Text("\(String(format: "%.1f", viewModel.overallConfidenceUsingStored()))%")
        //     .font(.title2)
        //     .bold()
        //     .foregroundColor(confidenceColor(viewModel.overallConfidenceUsingStored()))
        // }

        // Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("回答データセット")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(
            "\(viewModel.allParsedAnswersSets.count > 0 ? viewModel.allParsedAnswersSets.count : 1)セット"
          )
          .font(.title2)
          .bold()
          .foregroundColor(.primary)
        }

        Spacer()
        Button(action: {
          // CSV を生成して共有シートを表示
          do {
            // ViewModel 経由で CSV を生成
            // ViewModel に item をセットしていない場合は先にセット
            viewModel.setItem(
              item, allCroppedImageSets: allCroppedImageSets as [[Any]],
              allParsedAnswersSets: allParsedAnswersSets, allConfidenceScores: allConfidenceScores)
            let url = try viewModel.exportResponsesCSV(for: item)
            exportedFileURL = url
            isShowingShare = true
          } catch {
            print("CSV export failed: \(error)")
          }
        }) {
          Text("CSV出力")
            .font(.headline)
            .foregroundColor(ButtonForeground.color(for: colorScheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .glassEffect(.regular.interactive())
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
      }

      // アンケート情報
      VStack(alignment: .leading, spacing: 4) {
        if !item.title.isEmpty {
          Text("タイトル: \(item.title)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        Text("スキャン日時: \(formattedDate(item.timestamp))")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .padding()
    // カード背景：共通ユーティリティを使用してダーク/ライトに対応
    .background(CardBackground.color(for: colorScheme))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
  }

  // MARK: - Question Analysis Card
  /// 設問ごとの分析結果カード
  private func questionAnalysisCard(for questionIndex: Int) -> some View {
    let questionType = item.questionTypes[questionIndex]

    // ViewModel 経由でデータを取得
    let allAnswersForQuestion = viewModel.answersForQuestion(questionIndex)
    let allConfidenceForQuestion = viewModel.confidencesForQuestion(questionIndex)
    let allImagesForQuestion = viewModel.imagesDataForQuestion(questionIndex)

    // 設問タイプに応じて適切なコンポーネントを返す
    switch questionType {
    case .single(let question, let options):
      let summarizationState = viewModel.analysisResults.first(where: {
        $0.questionIndex == questionIndex
      })
      return AnyView(
        SingleQuestionAnalysisView(
          questionIndex: questionIndex,
          questionText: question,
          answers: allAnswersForQuestion,
          confidenceScores: allConfidenceForQuestion,
          images: allImagesForQuestion,
          options: options,
          isSummarizing: summarizationState?.isSummarizing ?? false,
          otherSummary: summarizationState?.otherSummary
        )
      )

    case .multiple(let question, let options):
      let summarizationState = viewModel.analysisResults.first(where: {
        $0.questionIndex == questionIndex
      })
      return AnyView(
        MultipleQuestionAnalysisView(
          questionIndex: questionIndex,
          questionText: question,
          answers: allAnswersForQuestion,
          confidenceScores: allConfidenceForQuestion,
          images: allImagesForQuestion,
          options: options,
          isSummarizing: summarizationState?.isSummarizing ?? false,
          otherSummary: summarizationState?.otherSummary
        )
      )

    case .text(let question):
      let summarizationState = viewModel.analysisResults.first(where: {
        $0.questionIndex == questionIndex
      })
      return AnyView(
        TextQuestionAnalysisView(
          questionIndex: questionIndex,
          questionText: question,
          answers: allAnswersForQuestion,
          confidenceScores: allConfidenceForQuestion,
          images: allImagesForQuestion,
          isSummarizing: summarizationState?.isSummarizing ?? false,
          otherSummary: summarizationState?.otherSummary
        )
      )

    case .info(let question, let options):
      return AnyView(
        InfoQuestionAnalysisView(
          questionIndex: questionIndex,
          questionText: question,
          answers: allAnswersForQuestion,
          confidenceScores: allConfidenceForQuestion,
          images: allImagesForQuestion,
          options: options.map { $0.displayName }
        )
      )
    }
  }

  // MARK: - Helper Methods

  /// 信頼度に応じた色を返す
  private func confidenceColor(_ confidence: Double) -> Color {
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

  /// 日付をフォーマットして返す
  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP_POSIX")
    formatter.dateFormat = "yyyy/M/d H:mm"
    return formatter.string(from: date)
  }
}

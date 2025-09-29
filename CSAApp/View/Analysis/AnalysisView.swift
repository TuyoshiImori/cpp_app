import SwiftData
import SwiftUI
import UIKit

/// 分析画面のView
/// Itemのスキャン結果を分析して表示します
struct AnalysisView: View {
  // MARK: - Properties
  @StateObject private var viewModel = AnalysisViewModel()
  @Environment(\.dismiss) private var dismiss

  let item: Item
  // 全ての回答データを保持
  let allCroppedImageSets: [[UIImage]]
  let allParsedAnswersSets: [[String]]
  let allConfidenceScores: [[Float]]?

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
  var body: some View {
    NavigationView {
      ZStack {
        // 背景色: ダーク/ライトに追随するシステムカラーを使用
        Color(.systemBackground)
          .ignoresSafeArea()

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

              // 設問ごとの分析結果を表示
              ForEach(0..<item.questionTypes.count, id: \.self) { questionIndex in
                questionAnalysisCard(for: questionIndex)
              }
            }
            .padding()
          }
        }
      }
      .navigationTitle("分析結果")
      .navigationBarTitleDisplayMode(.large)
    }
    .onAppear {
      // Viewが表示されたときにItemと全ての回答データを設定して分析開始
      viewModel.setItem(
        item,
        allCroppedImageSets: allCroppedImageSets as [[Any]],
        allParsedAnswersSets: allParsedAnswersSets,
        allConfidenceScores: allConfidenceScores
      )
    }
  }

  // MARK: - Summary Card
  private var summaryCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("分析サマリー")
        .font(.headline)
        .foregroundColor(.primary)

      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("全体信頼度")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(String(format: "%.1f", calculateOverallConfidence()))%")
            .font(.title2)
            .bold()
            .foregroundColor(confidenceColor(calculateOverallConfidence()))
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("回答データセット")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(allParsedAnswersSets.count > 0 ? allParsedAnswersSets.count : 1)セット")
            .font(.title2)
            .bold()
            .foregroundColor(.primary)
        }

        Spacer()
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
    // カードは secondarySystemBackground を使ってダーク/ライトに適応
    .background(Color(UIColor.secondarySystemBackground))
    .cornerRadius(12)
  }

  // MARK: - Question Analysis Card
  /// 設問ごとの分析結果カード
  private func questionAnalysisCard(for questionIndex: Int) -> some View {
    let questionType = item.questionTypes[questionIndex]

    // 全データセットから該当設問の回答を集める
    var allAnswersForQuestion: [String] = []
    var allConfidenceForQuestion: [Float] = []
    var allImagesForQuestion: [Data] = []

    if !allParsedAnswersSets.isEmpty {
      // 複数データセットがある場合
      for setIndex in 0..<allParsedAnswersSets.count {
        let answerSet = allParsedAnswersSets[setIndex]
        if questionIndex < answerSet.count {
          allAnswersForQuestion.append(answerSet[questionIndex])
        }

        if let confidenceScores = allConfidenceScores,
          setIndex < confidenceScores.count,
          questionIndex < confidenceScores[setIndex].count
        {
          allConfidenceForQuestion.append(confidenceScores[setIndex][questionIndex])
        }

        // 画像データがある場合
        if setIndex < allCroppedImageSets.count,
          questionIndex < allCroppedImageSets[setIndex].count
        {
          if let imageData = allCroppedImageSets[setIndex][questionIndex] as? UIImage {
            if let data = imageData.pngData() {
              allImagesForQuestion.append(data)
            }
          } else if let data = allCroppedImageSets[setIndex][questionIndex] as? Data {
            allImagesForQuestion.append(data)
          }
        }
      }
    } else {
      // 単一データセットの場合（従来の互換性）
      if let analysisResult = viewModel.analysisResults.first(where: {
        $0.questionIndex == questionIndex
      }) {
        allAnswersForQuestion = analysisResult.answers
        allConfidenceForQuestion = analysisResult.confidenceScores
      }
    }

    // 設問タイプに応じて適切なコンポーネントを返す
    switch questionType {
    case .single(let question, let options):
      // 該当設問の要約状態を ViewModel から取得して渡す
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
      // 該当設問の要約状態を ViewModel から取得して渡す
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
      // 該当設問の要約状態を ViewModel から取得して渡す
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

  /// 設問タイプのアイコンを返す
  private func questionTypeIcon(_ questionType: QuestionType) -> some View {
    Group {
      switch questionType {
      case .single(_, _):
        Image(systemName: "dot.circle")
          .foregroundColor(.blue)
      case .multiple(_, _):
        Image(systemName: "list.bullet")
          .foregroundColor(.green)
      case .text(_):
        Image(systemName: "textformat")
          .foregroundColor(.orange)
      case .info(_, _):
        Image(systemName: "person.crop.circle")
          .foregroundColor(.purple)
      }
    }
    .font(.title3)
  }

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

  /// QuestionTypeから設問文を取得
  private func getQuestionText(from questionType: QuestionType) -> String {
    switch questionType {
    case .single(let question, _), .multiple(let question, _), .text(let question),
      .info(let question, _):
      return question
    }
  }

  /// 全体の信頼度を計算
  private func calculateOverallConfidence() -> Double {
    guard let confidenceScores = allConfidenceScores, !confidenceScores.isEmpty else {
      return viewModel.overallConfidenceScore
    }

    var totalConfidence: Float = 0
    var totalCount = 0

    for setScores in confidenceScores {
      totalConfidence += setScores.reduce(0, +)
      totalCount += setScores.count
    }

    return totalCount > 0 ? Double(totalConfidence) / Double(totalCount) : 0.0
  }

  /// 有効回答数を計算
  private func calculateValidAnswerCount() -> Int {
    guard !allParsedAnswersSets.isEmpty else {
      return viewModel.validAnswerCount
    }

    var validCount = 0
    for answerSet in allParsedAnswersSets {
      validCount += answerSet.filter { !$0.isEmpty && $0 != "-1" }.count
    }
    return validCount
  }

  /// 総回答数を計算
  private func calculateTotalAnswerCount() -> Int {
    guard !allParsedAnswersSets.isEmpty else {
      return viewModel.totalAnswerCount
    }

    var totalCount = 0
    for answerSet in allParsedAnswersSets {
      totalCount += answerSet.count
    }
    return totalCount
  }
}

// MARK: - Preview
struct AnalysisView_Previews: PreviewProvider {
  static var previews: some View {
    // プレビュー用のダミーアイテム
    let dummyItem = Item(
      timestamp: Date(),
      questionTypes: [
        .single("好きな色は？", ["赤", "青", "緑"]),
        .text("ご意見をお聞かせください"),
      ],
      surveyID: "sample001",
      title: "サンプルアンケート"
    )

    AnalysisView(item: dummyItem)
  }
}

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

              // 全ての回答データがある場合は、データセット別に表示
              if !allParsedAnswersSets.isEmpty {
                ForEach(0..<allParsedAnswersSets.count, id: \.self) { setIndex in
                  dataSetCard(for: setIndex)
                }
              } else {
                // 従来通り：単一セットの分析結果
                ForEach(viewModel.analysisResults) { result in
                  analysisResultCard(result)
                }
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

        VStack(alignment: .trailing, spacing: 4) {
          Text("有効回答")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(calculateValidAnswerCount())/\(calculateTotalAnswerCount())")
            .font(.title2)
            .bold()
            .foregroundColor(.primary)
        }
      }

      // アンケート情報
      VStack(alignment: .leading, spacing: 4) {
        if !item.title.isEmpty {
          Text("タイトル: \(item.title)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        if !item.surveyID.isEmpty {
          Text("ID: \(item.surveyID)")
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

  // MARK: - Data Set Card
  /// データセット別の分析結果カード
  private func dataSetCard(for setIndex: Int) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      // データセットヘッダー
      HStack {
        Text("回答データ \(setIndex + 1)")
          .font(.largeTitle)
          .bold()
          .foregroundColor(.primary)

        Spacer()

        // データセットの信頼度
        if let confidenceScores = allConfidenceScores,
          setIndex < confidenceScores.count,
          !confidenceScores[setIndex].isEmpty
        {
          let avgConfidence =
            confidenceScores[setIndex].reduce(0, +) / Float(confidenceScores[setIndex].count)
          VStack(alignment: .trailing, spacing: 2) {
            Text("平均信頼度")
              .font(.caption)
              .foregroundColor(.secondary)
            Text("\(String(format: "%.1f", avgConfidence))%")
              .font(.headline)
              .bold()
              .foregroundColor(confidenceColor(Double(avgConfidence)))
          }
        }
      }

      // このデータセットの各設問
      if setIndex < allParsedAnswersSets.count {
        let answerSet = allParsedAnswersSets[setIndex]
        let confidenceSet =
          (allConfidenceScores != nil && setIndex < allConfidenceScores!.count)
          ? allConfidenceScores![setIndex] : []

        ForEach(0..<answerSet.count, id: \.self) { questionIndex in
          questionCard(
            questionIndex: questionIndex,
            answer: answerSet[questionIndex],
            confidence: questionIndex < confidenceSet.count ? confidenceSet[questionIndex] : 0.0,
            imageSet: setIndex < allCroppedImageSets.count ? allCroppedImageSets[setIndex] : []
          )
        }
      }
    }
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
    .cornerRadius(16)
  }

  // MARK: - Question Card
  /// 設問別の詳細カード
  private func questionCard(
    questionIndex: Int,
    answer: String,
    confidence: Float,
    imageSet: [UIImage]
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      // 設問ヘッダー
      HStack {
        Text("設問 \(questionIndex + 1)")
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()

        // 設問タイプアイコン（もしQuestionTypeが取得できるなら）
        if questionIndex < item.questionTypes.count {
          questionTypeIcon(item.questionTypes[questionIndex])
        }
      }

      // 設問文
      if questionIndex < item.questionTypes.count {
        Text(getQuestionText(from: item.questionTypes[questionIndex]))
          .font(.subheadline)
          .foregroundColor(.primary)
          .fixedSize(horizontal: false, vertical: true)
      }

      // 検出画像（ある場合）
      if questionIndex < imageSet.count {
        Image(uiImage: imageSet[questionIndex])
          .resizable()
          .scaledToFit()
          .frame(maxHeight: 150)
          .cornerRadius(8)
          .shadow(radius: 2)
      }

      // 回答結果
      VStack(alignment: .leading, spacing: 8) {
        Text("検出結果:")
          .font(.subheadline)
          .bold()
          .foregroundColor(.primary)

        HStack {
          Text(answer.isEmpty || answer == "-1" ? "未検出" : answer)
            .font(.body)
            .foregroundColor(answer.isEmpty || answer == "-1" ? .secondary : .primary)
            .fixedSize(horizontal: false, vertical: true)

          Spacer()

          if !answer.isEmpty && answer != "-1" {
            Text("\(String(format: "%.1f", confidence))%")
              .font(.caption)
              .bold()
              .foregroundColor(confidenceColor(Double(confidence)))
          }
        }
        .padding(.vertical, 4)
      }
    }
    .padding()
    .background(Color(UIColor.tertiarySystemBackground))
    .cornerRadius(12)
  }

  // MARK: - Analysis Result Card
  private func analysisResultCard(_ result: AnalysisViewModel.AnalysisResult) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      // 設問ヘッダー
      HStack {
        Text("設問 \(result.questionIndex + 1)")
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()

        // 設問タイプアイコン
        questionTypeIcon(result.questionType)
      }

      // 設問文
      Text(result.questionText)
        .font(.subheadline)
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)

      // 回答結果
      VStack(alignment: .leading, spacing: 8) {
        Text("検出結果:")
          .font(.subheadline)
          .bold()
          .foregroundColor(.primary)

        ForEach(result.answers.indices, id: \.self) { index in
          let answer = result.answers[index]
          let confidence =
            index < result.confidenceScores.count ? result.confidenceScores[index] : 0.0

          HStack {
            Text(answer.isEmpty || answer == "-1" ? "未検出" : answer)
              .font(.body)
              .foregroundColor(answer.isEmpty || answer == "-1" ? .secondary : .primary)

            Spacer()

            if !answer.isEmpty && answer != "-1" {
              Text("\(String(format: "%.1f", confidence))%")
                .font(.caption)
                .bold()
                .foregroundColor(confidenceColor(Double(confidence)))
            }
          }
          .padding(.vertical, 2)
        }
      }

      // 推奨事項（ある場合のみ表示）
      if !result.recommendations.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("推奨事項:")
            .font(.subheadline)
            .bold()
            .foregroundColor(.primary)

          ForEach(result.recommendations.indices, id: \.self) { index in
            Text("• \(result.recommendations[index])")
              .font(.caption)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding()
    // カードは secondarySystemBackground を使ってダーク/ライトに適応
    .background(Color(UIColor.secondarySystemBackground))
    .cornerRadius(12)
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

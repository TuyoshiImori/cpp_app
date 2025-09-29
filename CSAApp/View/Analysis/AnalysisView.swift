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
  var body: some View {
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
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: {
          // CSV を生成して共有シートを表示
          do {
            // questionTitles を item.questionTypes に基づき作成する
            var questionTitles: [String] = []
            for qt in item.questionTypes {
              switch qt {
              case .single(let question, _):
                questionTitles.append(question)
              case .multiple(let question, _):
                questionTitles.append(question)
              case .text(let question):
                questionTitles.append(question)
              case .info(_, let options):
                // info の場合は個人情報フィールドを設問ごとに列として展開
                for opt in options {
                  questionTitles.append(opt.displayName)
                }
              }
            }
            // 答えデータ: 既に外部から渡された全回答セットがあればそれを使用
            let answerSets: [[String]]
            if !allParsedAnswersSets.isEmpty {
              // 外部データが渡される場合、info 設問が1セルにまとまっている可能性があるため、
              // item.questionTypes に合わせて展開する
              answerSets = allParsedAnswersSets.map { debugExpandInfo($0) }
            } else {
              // viewModel.analysisResults を行ベースに変換
              answerSets = reconstructRows(from: viewModel.analysisResults)
            }

            let res = try CSVExporter.exportResponses(
              surveyTimestamp: item.timestamp,
              surveyTitle: item.title,
              questionTitles: questionTitles,
              allParsedAnswersSets: answerSets
            )
            exportedFileURL = res.url
            isShowingShare = true
          } catch {
            print("CSV export failed: \(error)")
          }
        }) {
          Image(systemName: "square.and.arrow.up")
        }
      }
    }
    .sheet(isPresented: $isShowingShare, onDismiss: { exportedFileURL = nil }) {
      if let url = exportedFileURL {
        ActivityView(activityItems: [url])
      } else {
        EmptyView()
      }
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

        // 画像データがある場合（allCroppedImageSets は UIImage の配列なので直接扱う）
        if setIndex < allCroppedImageSets.count,
          questionIndex < allCroppedImageSets[setIndex].count
        {
          let image = allCroppedImageSets[setIndex][questionIndex]
          if let data = image.pngData() {
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

  // MARK: - CSV Export Helpers
  /// AnalysisResult 配列から行ベースの回答セットを再構築する
  private func reconstructRows(from results: [AnalysisViewModel.AnalysisResult]) -> [[String]] {
    // item.questionTypes に合わせて列を展開する
    var expandedColumnsCount = 0
    for qt in item.questionTypes {
      switch qt {
      case .info(_, let options):
        expandedColumnsCount += options.count
      default:
        expandedColumnsCount += 1
      }
    }

    // 各設問ごとの最大行数を取得
    var maxRows = 0
    for r in results { maxRows = max(maxRows, r.answers.count) }

    var rows: [[String]] = []
    for rowIndex in 0..<maxRows {
      var row: [String] = []
      var resultIndex = 0
      for qt in item.questionTypes {
        let result = results[resultIndex]
        switch qt {
        case .info(_, let options):
          // info の回答は、1つの answers 要素に複数フィールドが入っている可能性がある
          // トップレベルのカンマのみで分割するユーティリティを使い、括弧や引用符内部のカンマを無視する
          let raw = rowIndex < result.answers.count ? result.answers[rowIndex] : ""
          let parts: [String]
          if raw.contains("\n") {
            // OpenCV/CameraViewModel が改行で返している場合は改行で分割する（PreviewFullScreenView と同様）
            parts = raw.components(separatedBy: "\n").map {
              $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
          } else {
            parts = StringUtils.splitTopLevel(
              raw, separators: Set([",", "、", "，", ";"]), omitEmptySubsequences: false
            )
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          }
          for i in 0..<options.count {
            if i < parts.count {
              row.append(parts[i])
            } else {
              row.append("")
            }
          }
        default:
          let raw = rowIndex < result.answers.count ? result.answers[rowIndex] : ""
          row.append(raw)
        }
        resultIndex += 1
      }
      rows.append(row)
    }
    return rows
  }

  /// 外部から渡された answerSet（1行）を item.questionTypes に合わせて展開する
  private func expandAnswerSetForInfo(_ answerSet: [String]) -> [String] {
    var expanded: [String] = []
    var idx = 0
    for qt in item.questionTypes {
      switch qt {
      case .info(_, let options):
        // 外部データでは 2 パターンある:
        // 1) info の複数フィールドが 1 セルにまとまっている（カンマ等で区切られている）
        // 2) 既に設問ごとに分割されて複数列になっている
        // 後者の可能性を優先的に検出して取り出す
        if idx + options.count <= answerSet.count {
          // 既に分割済みの列が存在する場合はそのまま取り出す
          for j in 0..<options.count {
            let raw = answerSet[idx + j]
            expanded.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
          }
          idx += options.count
        } else {
          // 単一セルにまとまっている場合はトップレベル分割を行う
          let raw = idx < answerSet.count ? answerSet[idx] : ""
          let parts: [String]
          if raw.contains("\n") {
            parts = raw.components(separatedBy: "\n").map {
              $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
          } else {
            parts = StringUtils.splitTopLevel(
              raw, separators: Set([",", "、", "，", ";"]), omitEmptySubsequences: false
            )
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          }
          for i in 0..<options.count {
            if i < parts.count {
              expanded.append(parts[i])
            } else {
              expanded.append("")
            }
          }
          idx += 1
        }
      default:
        // 通常の設問は 1 列
        let raw = idx < answerSet.count ? answerSet[idx] : ""
        expanded.append(raw)
        idx += 1
      }
    }
    return expanded
  }

  /// デバッグ用: info 展開結果をログ出力して返す
  private func debugExpandInfo(_ answerSet: [String]) -> [String] {
    let expanded = expandAnswerSetForInfo(answerSet)
    print("[Debug] expandAnswerSetForInfo input=\(answerSet)")
    print("[Debug] expandAnswerSetForInfo output=\(expanded)")
    return expanded
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

    NavigationStack {
      AnalysisView(item: dummyItem)
    }
  }
}

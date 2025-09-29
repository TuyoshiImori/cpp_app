import Foundation
import SwiftData
import SwiftUI

#if canImport(FoundationModels)
  import FoundationModels
#endif

// Itemモデルをimport
// 同じプロジェクト内なので直接参照可能

/// 分析画面用のViewModel
/// Itemの情報を受け取り、分析に必要な情報を管理します
@MainActor
class AnalysisViewModel: ObservableObject {
  // MARK: - Published Properties
  @Published var item: Item?
  @Published var isLoading: Bool = false
  @Published var analysisResults: [AnalysisResult] = []

  // MARK: - Analysis Result Model
  struct AnalysisResult: Identifiable {
    let id = UUID()
    let questionIndex: Int
    let questionText: String
    let questionType: QuestionType
    let answers: [String]
    let confidenceScores: [Float]
    let analysisScore: Double
    let recommendations: [String]
    // "その他" の LLM 要約結果（存在する場合）
    var otherSummary: String? = nil
    // 設問単位の要約処理中フラグ
    var isSummarizing: Bool = false
  }

  // MARK: - Computed Properties

  /// 全体の平均信頼度スコア
  var overallConfidenceScore: Double {
    guard !analysisResults.isEmpty else { return 0.0 }
    let totalScore = analysisResults.reduce(0.0) { sum, result in
      let avgConfidence =
        result.confidenceScores.isEmpty
        ? 0.0 : Double(result.confidenceScores.reduce(0, +)) / Double(result.confidenceScores.count)
      return sum + avgConfidence
    }
    return totalScore / Double(analysisResults.count)
  }

  /// 総回答数
  var totalAnswerCount: Int {
    analysisResults.reduce(0) { sum, result in
      sum + result.answers.count
    }
  }

  /// 有効回答数（空や未検出でない回答）
  var validAnswerCount: Int {
    analysisResults.reduce(0) { sum, result in
      sum + result.answers.filter { !$0.isEmpty && $0 != "-1" }.count
    }
  }

  // MARK: - Methods

  /// Itemを設定し、分析を開始する
  /// - Parameter item: 分析対象のItem
  /// - Parameter allCroppedImageSets: 全ての切り抜き画像セット
  /// - Parameter allParsedAnswersSets: 全ての解析済み回答セット
  /// - Parameter allConfidenceScores: 全ての信頼度スコアセット
  func setItem(
    _ item: Item,
    allCroppedImageSets: [[Any]] = [],
    allParsedAnswersSets: [[String]] = [],
    allConfidenceScores: [[Float]]? = nil
  ) {
    self.item = item
    performAnalysis(
      allCroppedImageSets: allCroppedImageSets,
      allParsedAnswersSets: allParsedAnswersSets,
      allConfidenceScores: allConfidenceScores
    )
  }

  /// 従来の互換性のためのメソッド
  func setItem(_ item: Item) {
    self.item = item
    performAnalysis()
  }

  /// 分析を実行する（全データセット対応版）
  private func performAnalysis(
    allCroppedImageSets: [[Any]] = [],
    allParsedAnswersSets: [[String]] = [],
    allConfidenceScores: [[Float]]? = nil
  ) {
    guard let item = item else { return }

    isLoading = true
    analysisResults = []

    // 全データセットがある場合は、それを使用
    if !allParsedAnswersSets.isEmpty {
      // 各設問について、全データセットを集約した分析結果を作成
      for (questionIndex, questionType) in item.questionTypes.enumerated() {
        var allAnswersForQuestion: [String] = []
        var allConfidenceForQuestion: [Float] = []

        // 全データセットから当該設問の回答を集める
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
        }

        let result = AnalysisResult(
          questionIndex: questionIndex,
          questionText: getQuestionText(from: questionType),
          questionType: questionType,
          answers: allAnswersForQuestion,
          confidenceScores: allConfidenceForQuestion,
          analysisScore: calculateAnalysisScore(
            for: questionType, answers: allAnswersForQuestion, confidence: allConfidenceForQuestion),
          recommendations: generateRecommendations(
            for: questionType, answers: allAnswersForQuestion, confidence: allConfidenceForQuestion)
        )

        analysisResults.append(result)
      }
    } else {
      // 従来通りの単一データセット分析
      performLegacyAnalysis()
    }

    isLoading = false
    // 分析が終わったら、必要に応じて各設問の "その他" を順番に要約する
    Task { @MainActor in
      await startLLMSummarizations()
    }
  }

  /// 全設問に対して、"その他" 自由記述がある場合は順番に要約を実行する
  /// 同一の要約処理が同時に走らないよう、actor ベースのキューで直列実行する
  func startLLMSummarizations() async {
    for idx in analysisResults.indices {
      let result = analysisResults[idx]
      switch result.questionType {
      case .single(_, let options):
        let agg = Self.aggregateSingleChoice(answers: result.answers, options: options)
        if !agg.otherTexts.isEmpty {
          // FoundationModels が利用できない環境では何もしない
          #if !canImport(FoundationModels)
            continue
          #else
            // 表示用にフラグを立てる
            analysisResults[idx].isSummarizing = true

            // actor 経由で順次要約を実行（質問インデックスと設問文を渡してログ出力させる）
            let summary = await SummarizationQueue.shared.summarize(
              otherTexts: agg.otherTexts,
              questionIndex: idx,
              questionText: result.questionText,
              questionKind: "single"
            )

            // nil が返った場合は何も表示しない（FoundationModels が使えない or エラー）
            if let s = summary {
              analysisResults[idx].otherSummary = s
            }
            analysisResults[idx].isSummarizing = false
          #endif
        }
      case .multiple(_, let options):
        let agg = Self.aggregateMultipleChoice(answers: result.answers, options: options)
        if !agg.otherTexts.isEmpty {
          #if !canImport(FoundationModels)
            continue
          #else
            analysisResults[idx].isSummarizing = true
            let summary = await SummarizationQueue.shared.summarize(
              otherTexts: agg.otherTexts,
              questionIndex: idx,
              questionText: result.questionText,
              questionKind: "multiple"
            )
            if let s = summary {
              analysisResults[idx].otherSummary = s
            }
            analysisResults[idx].isSummarizing = false
          #endif
        }
      default:
        continue
      }
    }
  }

  /// 従来の分析処理（後方互換性のため）
  private func performLegacyAnalysis() {
    guard let item = item else { return }

    // 最新のスキャン結果を取得
    let scanResult = item.getLatestScanResult()
    let answers = scanResult?.answerTexts ?? item.answerTexts
    let confidenceScores = scanResult?.confidenceScores ?? item.confidenceScores

    // 各設問について分析結果を作成
    for (index, questionType) in item.questionTypes.enumerated() {
      let questionAnswers = index < answers.count ? [answers[index]] : []
      let questionConfidence = index < confidenceScores.count ? [confidenceScores[index]] : []

      let result = AnalysisResult(
        questionIndex: index,
        questionText: getQuestionText(from: questionType),
        questionType: questionType,
        answers: questionAnswers,
        confidenceScores: questionConfidence,
        analysisScore: calculateAnalysisScore(
          for: questionType, answers: questionAnswers, confidence: questionConfidence),
        recommendations: generateRecommendations(
          for: questionType, answers: questionAnswers, confidence: questionConfidence)
      )

      analysisResults.append(result)
    }
  }

  /// 従来の分析を実行する（後方互換性のため）
  private func performAnalysis() {
    performAnalysis(
      allCroppedImageSets: [] as [[Any]], allParsedAnswersSets: [],
      allConfidenceScores: [] as [[Float]]?)
  }

  /// QuestionTypeから設問文を取得
  private func getQuestionText(from questionType: QuestionType) -> String {
    switch questionType {
    case .single(let question, _), .multiple(let question, _), .text(let question),
      .info(let question, _):
      return question
    }
  }

  /// 分析スコアを計算する
  private func calculateAnalysisScore(
    for questionType: QuestionType, answers: [String], confidence: [Float]
  ) -> Double {
    // 基本的な分析スコア計算ロジック
    let avgConfidence =
      confidence.isEmpty ? 0.0 : Double(confidence.reduce(0, +)) / Double(confidence.count)
    let hasValidAnswer = answers.contains { !$0.isEmpty && $0 != "-1" }

    return hasValidAnswer ? avgConfidence : 0.0
  }

  /// 推奨事項を生成する
  private func generateRecommendations(
    for questionType: QuestionType, answers: [String], confidence: [Float]
  ) -> [String] {
    var recommendations: [String] = []

    let avgConfidence = confidence.isEmpty ? 0.0 : confidence.reduce(0, +) / Float(confidence.count)
    let hasValidAnswer = answers.contains { !$0.isEmpty && $0 != "-1" }

    if !hasValidAnswer {
      recommendations.append("回答が検出されませんでした。画像品質を確認してください。")
    } else if avgConfidence < 60 {
      recommendations.append("検出の信頼度が低いです。より鮮明な画像での再スキャンを推奨します。")
    } else if avgConfidence >= 80 {
      recommendations.append("高い精度で検出されています。")
    }

    // 設問タイプ別の推奨事項
    switch questionType {
    case .single(_, let options):
      if options.count > 5 {
        recommendations.append("選択肢が多い設問です。回答の視認性を確認してください。")
      }
    case .multiple(_, let options):
      recommendations.append("複数選択の設問です。全ての選択項目が正しく検出されているか確認してください。")
    case .text(_):
      recommendations.append("自由記述の設問です。文字の判読性を確認してください。")
    case .info(_, let fields):
      if fields.count > 3 {
        recommendations.append("情報入力項目が多い設問です。各項目が正しく検出されているか確認してください。")
      }
    }

    return recommendations
  }

  /// 分析結果をリセット
  func resetAnalysis() {
    item = nil
    analysisResults = []
    isLoading = false
  }

  // MARK: - 単一選択設問のロジック
  // 使用対象: 単一選択設問 (.single)、および拡張として単純な集計を必要とする他の設問タイプ
  /// 単一選択設問の回答を集計し、円グラフ描画用のエントリを返す
  /// - Parameters:
  ///   - answers: 生の回答文字列配列（各回答セットから抽出した当該設問の値）
  ///   - options: 設問の選択肢ラベル配列
  /// - Returns: counts（ラベル->件数）, otherTexts（選択肢に一致しない自由記述）, entries（円グラフ用エントリ）, total（有効回答数）
  // ローカルの円グラフ用データ表現（UIに依存しない）
  struct PieChartData: Identifiable {
    let id = UUID()
    let label: String
    var value: Double
    var percent: Double
  }

  // MARK: - LLMの要約処理
  actor SummarizationQueue {
    static let shared = SummarizationQueue()
    private init() {}

    /// otherTexts を受け取り要約文字列を返す（直列実行が保証される）
    nonisolated func summarize(
      otherTexts: [String],
      questionIndex: Int,
      questionText: String,
      questionKind: String = "single"
    ) async -> String? {
      // FoundationModels が利用可能でない場合は nil を返して何もしない
      #if !canImport(FoundationModels)
        return nil
      #endif

      // FoundationModels が利用可能な場合のみ実行（ランタイムの OS バージョンも確認）
      if #available(iOS 17.0, macOS 14.0, *) {
        do {
          // プロンプトの組み立て: 設問情報と自由記述を番号付きリストで渡す
          // 要求: 出力を安定化するため、必ず固定の前置文で始め、その直後に1〜2文の要約を続けるよう指示する
          let promptHeaderBodySingle =
            "以下に示す“その他”に含まれる自由記述の主要なポイントを日本語で簡潔に要約してください。必ず応答文の先頭を次の文で始めてください：「その他の選択肢に記述された内容を要約しました。」その文の直後に要約を続け、全体で1〜2文に収めてください。冗長な前置きや余計な説明はせず、要点だけを書いてください。\n\n"
          let promptHeaderBodyMultiple =
            "以下に示す複数選択設問の“その他”に含まれる自由記述の主要なポイントを日本語で簡潔に要約してください。必ず応答文の先頭を次の文で始めてください：「その他の選択肢に記述された内容を要約しました。」その文の直後に要約を続け、全体で1〜2文に収めてください。複数のトピックがある場合は、最も頻出の観点を中心にまとめてください。冗長な前置きや余計な説明はせず、要点だけを書いてください。\n\n"

          let headerIntro = "設問 \(questionIndex + 1): \(questionText)\n"
          let promptHeader: String
          if questionKind.lowercased() == "multiple" {
            promptHeader = headerIntro + promptHeaderBodyMultiple
          } else {
            promptHeader = headerIntro + promptHeaderBodySingle
          }
          var bodyLines: [String] = []
          for (i, text) in otherTexts.enumerated() {
            let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let line = "[\(i+1)] \(sanitized)"
            bodyLines.append(line)
          }
          let inputs = bodyLines.joined(separator: "\n")
          let prompt = promptHeader + inputs

          // ログ出力: 実際に投げるプロンプトをログに出す
          print("[LLM] Prompt for questionIndex=\(questionIndex): \n\(prompt)")

          let session = LanguageModelSession()
          let response = try await session.respond(to: prompt)
          let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

          // ログ出力: 応答の抜粋をログに出す
          print("[LLM] Response for questionIndex=\(questionIndex): \n\(content)")

          if content.isEmpty { return nil }
          return content
        } catch {
          print("[LLM] Error summarizing for questionIndex=\(questionIndex): \(error)")
          return nil
        }
      } else {
        return nil
      }
    }
  }

  nonisolated static func aggregateSingleChoice(answers: [String], options: [String]) -> (
    counts: [String: Int], otherTexts: [String], entries: [PieChartData], total: Int
  ) {
    var dict: [String: Int] = [:]
    var otherTexts: [String] = []

    for raw in answers {
      let a = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if a.isEmpty || a == "-1" { continue }

      if let idx = Int(a), idx >= 0, idx < options.count {
        let label = options[idx]
        dict[label, default: 0] += 1
        continue
      }

      if let match = options.first(where: {
        $0.trimmingCharacters(in: .whitespacesAndNewlines) == a
      }) {
        dict[match, default: 0] += 1
        continue
      }

      // 選択肢に一致しないものは "その他"
      dict["その他", default: 0] += 1
      otherTexts.append(a)
    }

    let total = dict.values.reduce(0, +)

    // 円グラフ用エントリ作成
    // 並び順: 件数の多い順。件数が同じ場合は設問の選択肢の順番を保持する。
    // options に含まれるラベルの順序を優先し、含まれないキーは検出順を維持する。
    var optionPosition: [String: Int] = [:]
    for (i, opt) in options.enumerated() { optionPosition[opt] = i }

    // dict は挿入順を保持するので、それを検出順として使う
    var encounterOrder: [String] = []
    for k in dict.keys { encounterOrder.append(k) }

    func positionForKey(_ key: String) -> Int {
      if let p = optionPosition[key] { return p }
      if let idx = encounterOrder.firstIndex(of: key) { return options.count + idx }
      return options.count + encounterOrder.count
    }

    let sortedKeys = dict.keys.sorted { a, b in
      let ca = dict[a] ?? 0
      let cb = dict[b] ?? 0
      if ca != cb { return ca > cb }  // 件数多い順
      return positionForKey(a) < positionForKey(b)  // 同数は選択肢順
    }

    var entries: [PieChartData] = []
    for key in sortedKeys {
      let value = Double(dict[key] ?? 0)
      entries.append(PieChartData(label: key, value: value, percent: 0.0))
    }

    if total > 0 {
      for i in entries.indices {
        entries[i].percent = entries[i].value / Double(total) * 100.0
      }
    }

    return (counts: dict, otherTexts: otherTexts, entries: entries, total: total)
  }

  /// 複数選択設問の回答を集計する（各回答文字列に複数の選択肢が含まれる場合を想定）
  nonisolated static func aggregateMultipleChoice(answers: [String], options: [String]) -> (
    counts: [String: Int], otherTexts: [String], entries: [PieChartData], total: Int
  ) {
    var dict: [String: Int] = [:]
    var otherTexts: [String] = []

    for raw in answers {
      let a = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if a.isEmpty || a == "-1" { continue }

      // 分割: トップレベルのカンマ/スラッシュ/セミコロンで分割（括弧内は無視）
      let separators: Set<Character> = [Character(","), Character("/"), Character(";")]
      let parts = Self.splitTopLevel(a, separators: separators)
      let tokens = parts.isEmpty ? [a] : parts

      for token in tokens {
        if token.isEmpty { continue }

        if let idx = Int(token), idx >= 0, idx < options.count {
          let label = options[idx]
          dict[label, default: 0] += 1
          continue
        }

        if let match = options.first(where: {
          $0.trimmingCharacters(in: .whitespacesAndNewlines) == token
        }) {
          dict[match, default: 0] += 1
          continue
        }

        dict["その他", default: 0] += 1
        otherTexts.append(token)
      }
    }

    let total = dict.values.reduce(0, +)

    // 並び順: 件数の多い順。件数が同じ場合は設問の選択肢の順番を保持する。
    var optionPosition: [String: Int] = [:]
    for (i, opt) in options.enumerated() { optionPosition[opt] = i }
    var encounterOrder: [String] = []
    for k in dict.keys { encounterOrder.append(k) }

    func positionForKey(_ key: String) -> Int {
      if let p = optionPosition[key] { return p }
      if let idx = encounterOrder.firstIndex(of: key) { return options.count + idx }
      return options.count + encounterOrder.count
    }

    let sortedKeys = dict.keys.sorted { a, b in
      let ca = dict[a] ?? 0
      let cb = dict[b] ?? 0
      if ca != cb { return ca > cb }
      return positionForKey(a) < positionForKey(b)
    }

    var entries: [PieChartData] = []
    for key in sortedKeys {
      let value = Double(dict[key] ?? 0)
      entries.append(PieChartData(label: key, value: value, percent: 0.0))
    }

    if total > 0 {
      for i in entries.indices {
        entries[i].percent = entries[i].value / Double(total) * 100.0
      }
    }

    return (counts: dict, otherTexts: otherTexts, entries: entries, total: total)
  }

  // トップレベル分割のフォールバック実装。
  // 外部のユーティリティ（StringUtils）が存在すればそちらを使っても良いが、
  // ターゲット設定やコンパイル順序の問題で参照できない場合に備えて内部実装を提供する。
  nonisolated static func splitTopLevel(_ s: String, separators: Set<Character>) -> [String] {
    // ここでは単純に括弧/ブラケットのネストとクォートを無視する実装を行う
    var results: [String] = []
    var current = ""
    var depth = 0
    var inQuote: Character? = nil

    for ch in s {
      if let q = inQuote {
        current.append(ch)
        if ch == q { inQuote = nil }
        continue
      }

      if ch == "\"" || ch == "'" {
        inQuote = ch
        current.append(ch)
        continue
      }

      if ch == "(" || ch == "[" || ch == "{" {
        depth += 1
        current.append(ch)
        continue
      }

      if ch == ")" || ch == "]" || ch == "}" {
        if depth > 0 { depth -= 1 }
        current.append(ch)
        continue
      }

      if depth == 0 && separators.contains(ch) {
        let token = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty { results.append(token) }
        current = ""
      } else {
        current.append(ch)
      }
    }

    let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if !last.isEmpty { results.append(last) }
    return results
  }
}

// NOTE: 集計ロジックは AnalysisViewModel に実装しているため、ビューは
// AnalysisViewModel.aggregateSingleChoice / aggregateMultipleChoice を直接呼んでください。

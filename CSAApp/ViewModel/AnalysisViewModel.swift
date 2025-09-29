import Foundation
import SwiftData
import SwiftUI

#if canImport(FoundationModels)
  import FoundationModels
#endif

#if canImport(UIKit)
  import UIKit
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
  // 全データセット（UI から渡される可能性のあるデータ）を保存
  @Published var allCroppedImageSets: [[Any]] = []
  @Published var allParsedAnswersSets: [[String]] = []
  @Published var allConfidenceScores: [[Float]]? = nil

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
    // 受け取った全データセットを保持しておく
    self.allCroppedImageSets = allCroppedImageSets
    self.allParsedAnswersSets = allParsedAnswersSets
    self.allConfidenceScores = allConfidenceScores
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

        var result = AnalysisResult(
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

        // 作成時点で "その他" が存在する設問は、画面表示時点でローディングを表示するために事前にフラグを立てる
        switch questionType {
        case .single(_, let options):
          let agg = Self.aggregateSingleChoice(answers: allAnswersForQuestion, options: options)
          if !agg.otherTexts.isEmpty {
            result.isSummarizing = true
          }
        case .text(_):
          // 自由記述設問: 応答が存在する場合は画面表示時点で要約を走らせる想定なので事前マークする
          let nonEmpty = allAnswersForQuestion.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0 != "-1"
          }
          if !nonEmpty.isEmpty { result.isSummarizing = true }
        case .multiple(_, let options):
          let agg = Self.aggregateMultipleChoice(answers: allAnswersForQuestion, options: options)
          if !agg.otherTexts.isEmpty {
            result.isSummarizing = true
          }
        default:
          break
        }

        analysisResults.append(result)
      }
    } else {
      // 従来通りの単一データセット分析
      performLegacyAnalysis()
    }

    isLoading = false

    // 画面表示時点で、要約が行われる予定の設問（"その他" が存在するもの）については
    // UI 上で要約欄にローディングを表示するために事前にフラグを立てておく。
    // 実際の要約は従来通り順次実行される。
    for idx in analysisResults.indices {
      let res = analysisResults[idx]
      switch res.questionType {
      case .single(_, let options):
        let agg = Self.aggregateSingleChoice(answers: res.answers, options: options)
        if !agg.otherTexts.isEmpty {
          var m = analysisResults[idx]
          m.isSummarizing = true
          analysisResults[idx] = m
          print(
            "[AnalysisViewModel] Pre-marking isSummarizing for questionIndex=\(idx) (single), otherTextsCount=\(agg.otherTexts.count)"
          )
        }
      case .multiple(_, let options):
        let agg = Self.aggregateMultipleChoice(answers: res.answers, options: options)
        if !agg.otherTexts.isEmpty {
          var m = analysisResults[idx]
          m.isSummarizing = true
          analysisResults[idx] = m
          print(
            "[AnalysisViewModel] Pre-marking isSummarizing for questionIndex=\(idx) (multiple), otherTextsCount=\(agg.otherTexts.count)"
          )
        }
      default:
        break
      }
    }

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
            // 表示用にフラグを立てる（配列要素を取り出して変更→再代入）
            var m = analysisResults[idx]
            m.isSummarizing = true
            analysisResults[idx] = m

            // actor 経由で順次要約を実行（質問インデックスと設問文を渡してログ出力させる）
            let summary = await SummarizationQueue.shared.summarize(
              otherTexts: agg.otherTexts,
              questionIndex: idx,
              questionText: result.questionText,
              questionKind: "single"
            )

            // nil が返った場合は何も表示しない（FoundationModels が使えない or エラー）
            if let s = summary {
              var mm = analysisResults[idx]
              mm.otherSummary = s
              analysisResults[idx] = mm
            }

            var cleared = analysisResults[idx]
            cleared.isSummarizing = false
            analysisResults[idx] = cleared
          #endif
        }
      case .multiple(_, let options):
        let agg = Self.aggregateMultipleChoice(answers: result.answers, options: options)
        if !agg.otherTexts.isEmpty {
          #if !canImport(FoundationModels)
            continue
          #else
            var m = analysisResults[idx]
            m.isSummarizing = true
            analysisResults[idx] = m

            let summary = await SummarizationQueue.shared.summarize(
              otherTexts: agg.otherTexts,
              questionIndex: idx,
              questionText: result.questionText,
              questionKind: "multiple"
            )
            if let s = summary {
              var mm = analysisResults[idx]
              mm.otherSummary = s
              analysisResults[idx] = mm
            }

            var cleared = analysisResults[idx]
            cleared.isSummarizing = false
            analysisResults[idx] = cleared
          #endif
        }
      case .text(_):
        // 自由記述設問: 回答が存在する場合は順次要約を実行
        let nonEmpty = result.answers.filter {
          !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0 != "-1"
        }
        if !nonEmpty.isEmpty {
          #if !canImport(FoundationModels)
            continue
          #else
            var m = analysisResults[idx]
            m.isSummarizing = true
            analysisResults[idx] = m

            let summary = await SummarizationQueue.shared.summarize(
              otherTexts: nonEmpty,
              questionIndex: idx,
              questionText: result.questionText,
              questionKind: "text"
            )

            if let s = summary {
              var mm = analysisResults[idx]
              mm.otherSummary = s
              analysisResults[idx] = mm
            }

            var cleared = analysisResults[idx]
            cleared.isSummarizing = false
            analysisResults[idx] = cleared
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

      var result = AnalysisResult(
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

      // レガシー経路でも "その他" があれば画面表示時点でローディングを出す
      switch questionType {
      case .single(_, let options):
        let agg = Self.aggregateSingleChoice(answers: questionAnswers, options: options)
        if !agg.otherTexts.isEmpty { result.isSummarizing = true }
      case .multiple(_, let options):
        let agg = Self.aggregateMultipleChoice(answers: questionAnswers, options: options)
        if !agg.otherTexts.isEmpty { result.isSummarizing = true }
      default:
        break
      }

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
          let promptHeaderBodySingle =
            "以下に示す“その他”に含まれる自由記述の主要なポイントを日本語で簡潔に要約してください。必ず応答文の先頭を次の文で始めてください：「その他の選択肢に記述された内容を要約しました。」その文の直後に要約を続け、全体で1〜2文に収めてください。冗長な前置きや余計な説明はせず、要点だけを書いてください。\n\n"

          let promptHeaderBodyMultiple =
            "以下に示す複数選択設問の“その他”に含まれる自由記述の主要なポイントを日本語で簡潔に要約してください。必ず応答文の先頭を次の文で始めてください：「その他の選択肢に記述された内容を要約しました。」その文の直後に要約を続け、全体で1〜2文に収めてください。複数のトピックがある場合は、最も頻出の観点を中心にまとめてください。冗長な前置きや余計な説明はせず、要点だけを書いてください。\n\n"

          let promptHeaderBodyText =
            "以下に示す自由記述設問の回答（長文の意見や感想など）から主要なポイントを日本語で簡潔に要約してください。必ず応答文の先頭を次の文で始めてください：「印象に残った曲や出演者へのメッセージなど、主要なポイントを完結に要約しました。」その文の直後に要約を続け、全体で1〜2文に収めてください。複数のトピックがある場合は、最も頻出の観点を中心にまとめてください。冗長な前置きや余計な説明はせず、要点だけを書いてください。\n\n"

          let headerIntro = "設問 \(questionIndex + 1): \(questionText)\n"
          let kind = questionKind.lowercased()
          let promptHeader: String
          if kind == "multiple" {
            promptHeader = headerIntro + promptHeaderBodyMultiple
          } else if kind == "text" {
            promptHeader = headerIntro + promptHeaderBodyText
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

  // MARK: - View-facing helpers moved from AnalysisView

  /// 全体の信頼度（外部データが存在する場合はそれを優先）
  func overallConfidenceUsingStored() -> Double {
    if let confidenceScores = allConfidenceScores, !confidenceScores.isEmpty {
      var totalConfidence: Float = 0
      var totalCount = 0
      for set in confidenceScores {
        totalConfidence += set.reduce(0, +)
        totalCount += set.count
      }
      return totalCount > 0 ? Double(totalConfidence) / Double(totalCount) : 0.0
    }
    return overallConfidenceScore
  }

  /// 有効回答数（外部データが存在する場合はそれを優先）
  func validAnswerCountUsingStored() -> Int {
    if !allParsedAnswersSets.isEmpty {
      var valid = 0
      for answerSet in allParsedAnswersSets {
        valid += answerSet.filter { !$0.isEmpty && $0 != "-1" }.count
      }
      return valid
    }
    return validAnswerCount
  }

  /// 総回答数（外部データが存在する場合はそれを優先）
  func totalAnswerCountUsingStored() -> Int {
    if !allParsedAnswersSets.isEmpty {
      var total = 0
      for answerSet in allParsedAnswersSets { total += answerSet.count }
      return total
    }
    return totalAnswerCount
  }

  /// 指定設問の回答リストを返す（外部データがある場合はそちらを優先して抽出）
  func answersForQuestion(_ questionIndex: Int) -> [String] {
    var answers: [String] = []
    if !allParsedAnswersSets.isEmpty {
      for set in allParsedAnswersSets {
        if questionIndex < set.count {
          answers.append(set[questionIndex])
        } else {
          answers.append("")
        }
      }
      return answers
    }

    if let r = analysisResults.first(where: { $0.questionIndex == questionIndex }) {
      return r.answers
    }
    return []
  }

  /// 指定設問の信頼度リストを返す
  func confidencesForQuestion(_ questionIndex: Int) -> [Float] {
    var confidences: [Float] = []
    if let all = allConfidenceScores, !all.isEmpty {
      for set in all {
        if questionIndex < set.count {
          confidences.append(set[questionIndex])
        }
      }
      return confidences
    }

    if let r = analysisResults.first(where: { $0.questionIndex == questionIndex }) {
      return r.confidenceScores
    }
    return []
  }

  /// 指定設問の画像データ（PNG）配列を返す
  func imagesDataForQuestion(_ questionIndex: Int) -> [Data] {
    var images: [Data] = []
    if !allCroppedImageSets.isEmpty {
      for set in allCroppedImageSets {
        if questionIndex < set.count {
          if let img = set[questionIndex] as? UIImage, let d = img.pngData() {
            images.append(d)
          }
        }
      }
      return images
    }

    // レガシーパスでは analysisResults に UIImage は含まれていないため空を返す
    return images
  }

  /// AnalysisResult 配列から行ベースの回答セットを再構築する（View で使う）
  func reconstructRowsFromAnalysisResults() -> [[String]] {
    guard let item = item else { return [] }

    var expandedColumnsCount = 0
    for qt in item.questionTypes {
      switch qt {
      case .info(_, let options): expandedColumnsCount += options.count
      default: expandedColumnsCount += 1
      }
    }

    var maxRows = 0
    for r in analysisResults { maxRows = max(maxRows, r.answers.count) }

    var rows: [[String]] = []
    for rowIndex in 0..<maxRows {
      var row: [String] = []
      var resultIndex = 0
      for qt in item.questionTypes {
        let result = analysisResults[resultIndex]
        switch qt {
        case .info(_, let options):
          let raw = rowIndex < result.answers.count ? result.answers[rowIndex] : ""
          let parts: [String]
          if raw.contains("\n") {
            parts = raw.components(separatedBy: "\n").map {
              $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
          } else {
            parts = Self.splitTopLevel(raw, separators: Set([",", "、", "，", ";"]))
              .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          }
          for i in 0..<options.count {
            if i < parts.count { row.append(parts[i]) } else { row.append("") }
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
  func expandAnswerSetForInfo(_ answerSet: [String]) -> [String] {
    guard let item = item else { return answerSet }
    var expanded: [String] = []
    var idx = 0
    for qt in item.questionTypes {
      switch qt {
      case .info(_, let options):
        if idx + options.count <= answerSet.count {
          for j in 0..<options.count {
            let raw = answerSet[idx + j]
            expanded.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
          }
          idx += options.count
        } else {
          let raw = idx < answerSet.count ? answerSet[idx] : ""
          let parts: [String]
          if raw.contains("\n") {
            parts = raw.components(separatedBy: "\n").map {
              $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
          } else {
            parts = Self.splitTopLevel(raw, separators: Set([",", "、", "，", ";"]))
              .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          }
          for i in 0..<options.count {
            if i < parts.count { expanded.append(parts[i]) } else { expanded.append("") }
          }
          idx += 1
        }
      default:
        let raw = idx < answerSet.count ? answerSet[idx] : ""
        expanded.append(raw)
        idx += 1
      }
    }
    return expanded
  }

  /// CSV 出力ラッパー: item を用いて CSV を生成しファイル URL を返す
  func exportResponsesCSV(for item: Item) throws -> URL {
    // questionTitles の作成
    var questionTitles: [String] = []
    for qt in item.questionTypes {
      switch qt {
      case .single(let question, _): questionTitles.append(question)
      case .multiple(let question, _): questionTitles.append(question)
      case .text(let question): questionTitles.append(question)
      case .info(_, let options): for opt in options { questionTitles.append(opt.displayName) }
      }
    }

    let answerSets: [[String]]
    if !allParsedAnswersSets.isEmpty {
      // 展開が必要な info を展開
      answerSets = allParsedAnswersSets.map { expandAnswerSetForInfo($0) }
    } else {
      answerSets = reconstructRowsFromAnalysisResults()
    }

    let res = try CSVExporter.exportResponses(
      surveyTimestamp: item.timestamp,
      surveyTitle: item.title,
      questionTitles: questionTitles,
      allParsedAnswersSets: answerSets
    )
    return res.url
  }
}

// NOTE: 集計ロジックは AnalysisViewModel に実装しているため、ビューは
// AnalysisViewModel.aggregateSingleChoice / aggregateMultipleChoice を直接呼んでください。

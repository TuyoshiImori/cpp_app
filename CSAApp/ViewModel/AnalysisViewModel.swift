import Foundation
import SwiftData
import SwiftUI

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
  func setItem(_ item: Item) {
    self.item = item
    performAnalysis()
  }

  /// 分析を実行する
  private func performAnalysis() {
    guard let item = item else { return }

    isLoading = true
    analysisResults = []

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

    isLoading = false
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
}

import Foundation
import SwiftUI

/// CSV を生成するユーティリティ。将来的に別フォーマットを追加しやすいように Exporter プロトコルを想定できる作りにしている。
struct CSVExporter {
  struct ExportResult {
    let url: URL
  }

  /// 指定の設問と回答データから CSV を生成し、テンポラリファイルに書き出してその URL を返す
  /// - Parameters:
  ///   - item: 対象の Item
  ///   - analysisResults: ViewModel の分析結果（設問情報を含む）
  ///   - allParsedAnswersSets: 元の全回答セット（行ごと）
  /// - Returns: ExportResult (ファイル URL) または nil
  static func exportResponses(
    surveyTimestamp: Date,
    surveyTitle: String,
    questionTitles: [String],
    allParsedAnswersSets: [[String]]
  ) throws -> ExportResult {
    // ヘッダー行: 設問タイトルを列にする
    var columns: [String] = ["番号", "タイムスタンプ"]
    columns.append(contentsOf: questionTitles)

    var csvRows: [[String]] = []
    csvRows.append(columns)

    // 各回答セットを行として追加。answerSets の行長が設問数と一致しない場合は空欄で埋める
    for (rowIndex, answerSet) in allParsedAnswersSets.enumerated() {
      var row: [String] = []
      // 行番号を 1 始まりで追加
      row.append("\(rowIndex + 1)")
      // タイムスタンプは共通の surveyTimestamp を採用（将来的に行ごとのタイムスタンプ対応も可能）
      let formatter = DateFormatter()
      // CSV 内のタイムスタンプはyyyyMMddhhmmss
      // ユーザー指定のフォーマットに合わせるため 'hh' を使用します。
      formatter.locale = Locale(identifier: "ja_JP_POSIX")
      formatter.dateFormat = "yyyyMMddhhmmss"
      row.append(formatter.string(from: surveyTimestamp))

      for qIndex in 0..<questionTitles.count {
        if qIndex < answerSet.count {
          // CSV 用にカンマ・改行・ダブルクオートをエスケープ
          row.append(escapeCSVField(answerSet[qIndex]))
        } else {
          row.append("")
        }
      }

      csvRows.append(row)
    }

    // CSV 文字列を生成
    let csvString = csvRows.map { $0.joined(separator: ",") }.joined(separator: "\n")

    // 一時ファイルに書き出す
    let tmpDir = FileManager.default.temporaryDirectory
    // ファイル名に使うタイトルは surveyTitle を優先して利用。
    // surveyTitle にファイル名に使えない文字（/, :, \\ など）が含まれる可能性があるため
    // セーフ化する: スラッシュとコロンは視認性を保つため全角に置換する。また不要な空白は '_' に置換。
    var safeTitle = surveyTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    if safeTitle.isEmpty { safeTitle = "Survey" }
    safeTitle = safeTitle.replacingOccurrences(of: "/", with: "／")
    safeTitle = safeTitle.replacingOccurrences(of: ":", with: "：")
    safeTitle = safeTitle.replacingOccurrences(of: "\\", with: "_")
    safeTitle = safeTitle.replacingOccurrences(of: "\n", with: "_")
    // ファイル名に含める日付文字列
    let now = Date()
    let fileDateFormatter = DateFormatter()
    fileDateFormatter.locale = Locale(identifier: "ja_JP_POSIX")
    // ファイル名用の日付はyyyyMMddhhmmss
    fileDateFormatter.dateFormat = "yyyyMMddhhmmss"
    let fileDateRaw = fileDateFormatter.string(from: now)
    // 半角の '/' と ':' をファイル名に安全な全角に置換
    let fileDateSafe = fileDateRaw.replacingOccurrences(of: "/", with: "／").replacingOccurrences(
      of: ":", with: "：")
    let fileName = "\(safeTitle)_\(fileDateSafe).csv"
    let fileURL = tmpDir.appendingPathComponent(fileName)

    try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
    return ExportResult(url: fileURL)
  }

  private static func escapeCSVField(_ field: String) -> String {
    var s = field
    if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
      s = s.replacingOccurrences(of: "\"", with: "\"\"")
      s = "\"\(s)\""
    }
    return s
  }
}

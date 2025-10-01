import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// テキスト入力設問の分析結果を表示するコンポーネント
struct TextQuestionAnalysisView: View {
  let questionIndex: Int
  let questionText: String
  let answers: [String]
  let confidenceScores: [Float]
  let images: [Data]
  // 要約中フラグ（ViewModel から渡される）
  var isSummarizing: Bool = false
  // 要約文（要約完了後に表示）
  var otherSummary: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 設問ヘッダー
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "textformat")
          .foregroundColor(.orange)
          .font(.title2)
        Text(questionText)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
      }
      VStack(alignment: .leading, spacing: 6) {
        // 要約表示領域（single/multiple と同様にカード内に含める）
        if isSummarizing {
          HStack {
            ProgressView()
              .scaleEffect(0.9)
            Text("要約を取得中...")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        } else if let s = otherSummary {
          VStack(alignment: .leading, spacing: 6) {
            Text("要約:")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
            Text(s)
              .font(.subheadline)
              .foregroundColor(.primary)
              .fixedSize(horizontal: false, vertical: true)
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        // 回答率（右下表示）
        HStack {
          Spacer()
          let validCount = answers.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0 != "-1"
          }.count
          Text("回答率: \(validCount)/\(answers.count)")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
  }
}

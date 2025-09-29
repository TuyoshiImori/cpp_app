import SwiftUI

/// テキスト入力設問の分析結果を表示するコンポーネント
struct TextQuestionAnalysisView: View {
  let questionIndex: Int
  let questionText: String
  let answers: [String]
  let confidenceScores: [Float]
  let images: [Data]
  // 要約中フラグ（ViewModel から渡される）
  let isSummarizing: Bool
  // 要約文（要約完了後に表示）
  let otherSummary: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 設問ヘッダー
      HStack {
        Image(systemName: "textformat")
          .foregroundColor(.orange)
          .font(.title3)

        Text("設問 \(questionIndex + 1) (自由記述)")
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()
      }

      // 設問文
      Text(questionText)
        .font(.subheadline)
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }

    // 要約表示領域
    VStack(alignment: .leading, spacing: 8) {
      if isSummarizing {
        HStack {
          ProgressView().scaleEffect(0.9)
          Text("要約を取得中...")
        }
      } else if let s = otherSummary {
        Text(s)
          .font(.body)
          .foregroundColor(.primary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding([.leading, .trailing, .bottom])

    .padding()
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(12)
  }
}

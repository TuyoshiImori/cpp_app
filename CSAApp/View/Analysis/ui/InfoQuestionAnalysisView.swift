import SwiftUI

/// 情報入力設問（名前、年齢など）の分析結果を表示するコンポーネント
struct InfoQuestionAnalysisView: View {
  let questionIndex: Int
  let questionText: String
  let answers: [String]
  let confidenceScores: [Float]
  let images: [Data]
  let options: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 設問ヘッダー
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "person.crop.circle")
          .foregroundColor(.purple)
          .font(.title2)
        Text(questionText)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
      }
      // 選択肢がある場合は表示（年代選択など）
      if !options.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("選択肢:")
            .font(.caption)
            .bold()
            .foregroundColor(.secondary)

          ForEach(options.indices, id: \.self) { index in
            Text("• \(options[index])")
              .font(.caption)
              .foregroundColor(.secondary)
          }
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
    .padding()
  }
}

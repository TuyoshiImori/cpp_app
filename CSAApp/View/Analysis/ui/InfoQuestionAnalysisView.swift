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
      HStack {
        Image(systemName: "person.crop.circle")
          .foregroundColor(.purple)
          .font(.title3)

        Text("設問 \(questionIndex + 1) (個人情報)")
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()
      }

      // 設問文
      Text(questionText)
        .font(.subheadline)
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)

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
    }
  .padding()
#if canImport(UIKit)
  .background(Color(UIColor.secondarySystemBackground))
#else
  .background(Color.secondary.opacity(0.1))
#endif
  .cornerRadius(12)
  }
}

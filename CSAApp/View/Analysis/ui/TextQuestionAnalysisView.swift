import SwiftUI

/// テキスト入力設問の分析結果を表示するコンポーネント
struct TextQuestionAnalysisView: View {
  let questionIndex: Int
  let questionText: String
  let answers: [String]
  let confidenceScores: [Float]
  let images: [Data]

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

      // 検出画像がある場合は表示
      if !images.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(images.indices, id: \.self) { index in
              VStack {
                // 画像プレースホルダー
                Rectangle()
                  .fill(Color.gray.opacity(0.3))
                  .overlay(
                    Image(systemName: "photo")
                      .foregroundColor(.gray)
                  )
                  .frame(maxHeight: 120)
                  .cornerRadius(8)
                  .shadow(radius: 2)

                Text("回答 \(index + 1)")
                  .font(.caption2)
                  .foregroundColor(.secondary)
              }
            }
          }
          .padding(.horizontal)
        }
      }

      // 検出結果の表示
      VStack(alignment: .leading, spacing: 8) {
        Text("検出結果:")
          .font(.subheadline)
          .bold()
          .foregroundColor(.primary)

        ForEach(answers.indices, id: \.self) { index in
          let answer = answers[index]
          let confidence = index < confidenceScores.count ? confidenceScores[index] : 0.0

          VStack(alignment: .leading, spacing: 8) {
            // データセット番号と信頼度
            HStack {
              Text("データ\(index + 1):")
                .font(.caption)
                .foregroundColor(.secondary)

              Spacer()

              if !answer.isEmpty && answer != "-1" {
                Text("\(String(format: "%.1f", confidence))%")
                  .font(.caption)
                  .bold()
                  .foregroundColor(confidenceColor(Double(confidence)))
                  .padding(.horizontal, 8)
                  .padding(.vertical, 2)
                  .background(confidenceColor(Double(confidence)).opacity(0.1))
                  .cornerRadius(4)
              }
            }

            // 回答テキスト
            if answer.isEmpty || answer == "-1" {
              Text("未検出")
                .font(.body)
                .foregroundColor(.secondary)
                .italic()
            } else {
              Text(answer)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .fixedSize(horizontal: false, vertical: true)

              // 文字数カウント
              Text("文字数: \(answer.count)文字")
                .font(.caption2)
                .foregroundColor(.secondary)
            }
          }
          .padding(.vertical, 6)
        }

        // 統計情報
        if answers.count > 1 {
          statisticsView
        }
      }
    }
    .padding()
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(12)
  }

  /// 統計情報表示
  private var statisticsView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("統計:")
        .font(.caption)
        .bold()
        .foregroundColor(.secondary)

      HStack {
        // 検出率
        let detectionRate =
          Double(answers.filter { !$0.isEmpty && $0 != "-1" }.count) / Double(answers.count) * 100
        Text("検出率: \(String(format: "%.1f", detectionRate))%")
          .font(.caption)
          .foregroundColor(.secondary)

        Spacer()

        // 平均信頼度
        if !confidenceScores.isEmpty {
          let avgConfidence = confidenceScores.reduce(0, +) / Float(confidenceScores.count)
          Text("平均信頼度: \(String(format: "%.1f", avgConfidence))%")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      // テキスト分析
      let validAnswers = answers.filter { !$0.isEmpty && $0 != "-1" }
      if !validAnswers.isEmpty {
        let avgLength =
          Double(validAnswers.reduce(0) { $0 + $1.count }) / Double(validAnswers.count)
        Text("平均文字数: \(String(format: "%.1f", avgLength))文字")
          .font(.caption)
          .foregroundColor(.secondary)

        let maxLength = validAnswers.map { $0.count }.max() ?? 0
        let minLength = validAnswers.map { $0.count }.min() ?? 0
        Text("文字数範囲: \(minLength) - \(maxLength)文字")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(.top, 4)
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
}

/// プレビュー
struct TextQuestionAnalysisView_Previews: PreviewProvider {
  static var previews: some View {
    TextQuestionAnalysisView(
      questionIndex: 2,
      questionText: "今回のサービスについてご意見をお聞かせください",
      answers: ["とても満足しています。使いやすく機能も充実していました。", "普通だと思います", "未検出"],
      confidenceScores: [92.0, 78.0, 0.0],
      images: []
    )
    .padding()
  }
}

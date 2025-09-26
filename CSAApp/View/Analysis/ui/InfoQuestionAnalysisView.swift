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
                  .frame(maxHeight: 100)
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

          VStack(alignment: .leading, spacing: 6) {
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

            // 回答内容
            HStack {
              if answer.isEmpty || answer == "-1" {
                Text("未検出")
                  .font(.body)
                  .foregroundColor(.secondary)
                  .italic()
              } else {
                // 個人情報のため、プライバシーに配慮した表示
                Text(maskPersonalInfo(answer))
                  .font(.body)
                  .foregroundColor(.primary)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(Color.purple.opacity(0.1))
                  .cornerRadius(6)
                  .overlay(
                    RoundedRectangle(cornerRadius: 6)
                      .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                  )
              }

              Spacer()
            }

            // データタイプの推定
            if !answer.isEmpty && answer != "-1" {
              Text("タイプ: \(detectDataType(answer))")
                .font(.caption2)
                .foregroundColor(.secondary)
            }
          }
          .padding(.vertical, 4)
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

  /// 個人情報をマスクする（プライバシー保護）
  private func maskPersonalInfo(_ info: String) -> String {
    // 数字が連続している場合は年齢や電話番号の可能性があるのでマスク
    if info.allSatisfy({ $0.isNumber }) && info.count >= 2 {
      if info.count <= 3 {
        // 年齢の場合（2-3桁）
        return info + "歳"
      } else {
        // 電話番号などの場合
        return String(info.prefix(3)) + "****"
      }
    }

    // 文字列の場合は部分的にマスク
    if info.count > 4 {
      return String(info.prefix(2)) + "***" + String(info.suffix(1))
    } else if info.count > 2 {
      return String(info.prefix(1)) + "**" + String(info.suffix(1))
    }

    return info
  }

  /// データタイプを推定する
  private func detectDataType(_ data: String) -> String {
    if data.allSatisfy({ $0.isNumber }) {
      if data.count <= 3 {
        return "年齢"
      } else if data.count >= 10 {
        return "電話番号"
      } else {
        return "数値"
      }
    } else if data.contains("@") {
      return "メールアドレス"
    } else if data.count >= 2 && data.count <= 20 {
      return "氏名"
    } else {
      return "テキスト"
    }
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

      // データタイプ分析
      let validAnswers = answers.filter { !$0.isEmpty && $0 != "-1" }
      if !validAnswers.isEmpty {
        let dataTypes = validAnswers.map { detectDataType($0) }
        let uniqueTypes = Set(dataTypes)
        Text("検出されたデータタイプ: \(uniqueTypes.joined(separator: ", "))")
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
struct InfoQuestionAnalysisView_Previews: PreviewProvider {
  static var previews: some View {
    InfoQuestionAnalysisView(
      questionIndex: 3,
      questionText: "お名前を教えてください",
      answers: ["田中太郎", "佐藤花子", "未検出"],
      confidenceScores: [95.0, 88.0, 0.0],
      images: [],
      options: []
    )
    .padding()

    InfoQuestionAnalysisView(
      questionIndex: 4,
      questionText: "年齢を選択してください",
      answers: ["25", "30", "42"],
      confidenceScores: [90.0, 87.0, 83.0],
      images: [],
      options: ["20代", "30代", "40代", "50代"]
    )
    .padding()
  }
}

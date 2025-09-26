import SwiftUI

/// 複数選択設問の分析結果を表示するコンポーネント
struct MultipleQuestionAnalysisView: View {
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
        Image(systemName: "list.bullet")
          .foregroundColor(.green)
          .font(.title3)

        Text("設問 \(questionIndex + 1) (複数選択)")
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()
      }

      // 設問文
      Text(questionText)
        .font(.subheadline)
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)

      // 選択肢の表示
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

          VStack(alignment: .leading, spacing: 4) {
            // データセット番号
            Text("データ\(index + 1):")
              .font(.caption)
              .foregroundColor(.secondary)

            // 選択された項目を解析して表示
            if !answer.isEmpty && answer != "-1" {
              let selectedItems = parseMultipleSelections(answer)
              if selectedItems.isEmpty {
                Text("未検出")
                  .font(.body)
                  .foregroundColor(.secondary)
              } else {
                VStack(alignment: .leading, spacing: 2) {
                  ForEach(selectedItems.indices, id: \.self) { itemIndex in
                    HStack {
                      Text("• \(selectedItems[itemIndex])")
                        .font(.body)
                        .foregroundColor(.primary)

                      Spacer()

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
                }
              }
            } else {
              Text("未検出")
                .font(.body)
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

  /// 複数選択の回答をパースする
  private func parseMultipleSelections(_ answer: String) -> [String] {
    // カンマ区切りや改行区切りを想定
    let separators = CharacterSet(charactersIn: ",\n;")
    return answer.components(separatedBy: separators)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
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

      // 選択された項目の分析
      let allSelectedItems = answers.compactMap { answer in
        answer.isEmpty || answer == "-1" ? nil : parseMultipleSelections(answer)
      }.flatMap { $0 }

      if !allSelectedItems.isEmpty {
        let uniqueItems = Set(allSelectedItems)
        Text("選択された項目数: \(uniqueItems.count)種類")
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
struct MultipleQuestionAnalysisView_Previews: PreviewProvider {
  static var previews: some View {
    MultipleQuestionAnalysisView(
      questionIndex: 1,
      questionText: "興味のある分野を選択してください（複数選択可）",
      answers: ["プログラミング,デザイン", "プログラミング", "未検出"],
      confidenceScores: [88.0, 75.0, 0.0],
      images: [],
      options: ["プログラミング", "デザイン", "マーケティング", "営業"]
    )
    .padding()
  }
}

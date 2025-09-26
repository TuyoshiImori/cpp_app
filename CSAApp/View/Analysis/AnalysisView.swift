import SwiftData
import SwiftUI

/// 分析画面のView
/// Itemのスキャン結果を分析して表示します
struct AnalysisView: View {
  // MARK: - Properties
  @StateObject private var viewModel = AnalysisViewModel()
  @Environment(\.dismiss) private var dismiss

  let item: Item

  // MARK: - Initializer
  init(item: Item) {
    self.item = item
  }

  // MARK: - Body
  var body: some View {
    NavigationView {
      ZStack {
        // 背景色
        Color.gray.opacity(0.1)
          .ignoresSafeArea()

        if viewModel.isLoading {
          // ローディング表示
          VStack {
            ProgressView()
              .scaleEffect(1.5)
            Text("分析中...")
              .font(.headline)
              .padding(.top)
          }
        } else {
          // メインコンテンツ
          ScrollView {
            VStack(spacing: 20) {
              // サマリーカード
              summaryCard

              // 各設問の分析結果
              ForEach(viewModel.analysisResults) { result in
                analysisResultCard(result)
              }
            }
            .padding()
          }
        }
      }
      .navigationTitle("分析結果")
      .navigationBarTitleDisplayMode(.large)
    }
    .onAppear {
      // Viewが表示されたときにItemを設定して分析開始
      viewModel.setItem(item)
    }
  }

  // MARK: - Summary Card
  private var summaryCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("分析サマリー")
        .font(.headline)
        .foregroundColor(.primary)

      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("全体信頼度")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(String(format: "%.1f", viewModel.overallConfidenceScore))%")
            .font(.title2)
            .bold()
            .foregroundColor(confidenceColor(viewModel.overallConfidenceScore))
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("有効回答")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(viewModel.validAnswerCount)/\(viewModel.totalAnswerCount)")
            .font(.title2)
            .bold()
            .foregroundColor(.primary)
        }
      }

      // アンケート情報
      VStack(alignment: .leading, spacing: 4) {
        if !item.title.isEmpty {
          Text("タイトル: \(item.title)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        if !item.surveyID.isEmpty {
          Text("ID: \(item.surveyID)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        Text("スキャン日時: \(formattedDate(item.timestamp))")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .padding()
    .background(Color.white)
    .cornerRadius(12)
  }

  // MARK: - Analysis Result Card
  private func analysisResultCard(_ result: AnalysisViewModel.AnalysisResult) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      // 設問ヘッダー
      HStack {
        Text("設問 \(result.questionIndex + 1)")
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()

        // 設問タイプアイコン
        questionTypeIcon(result.questionType)
      }

      // 設問文
      Text(result.questionText)
        .font(.subheadline)
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)

      // 回答結果
      VStack(alignment: .leading, spacing: 8) {
        Text("検出結果:")
          .font(.subheadline)
          .bold()
          .foregroundColor(.primary)

        ForEach(result.answers.indices, id: \.self) { index in
          let answer = result.answers[index]
          let confidence =
            index < result.confidenceScores.count ? result.confidenceScores[index] : 0.0

          HStack {
            Text(answer.isEmpty || answer == "-1" ? "未検出" : answer)
              .font(.body)
              .foregroundColor(answer.isEmpty || answer == "-1" ? .secondary : .primary)

            Spacer()

            if !answer.isEmpty && answer != "-1" {
              Text("\(String(format: "%.1f", confidence))%")
                .font(.caption)
                .bold()
                .foregroundColor(confidenceColor(Double(confidence)))
            }
          }
          .padding(.vertical, 2)
        }
      }

      // 推奨事項（ある場合のみ表示）
      if !result.recommendations.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("推奨事項:")
            .font(.subheadline)
            .bold()
            .foregroundColor(.primary)

          ForEach(result.recommendations.indices, id: \.self) { index in
            Text("• \(result.recommendations[index])")
              .font(.caption)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding()
    .background(Color.white)
    .cornerRadius(12)
  }

  // MARK: - Helper Methods

  /// 設問タイプのアイコンを返す
  private func questionTypeIcon(_ questionType: QuestionType) -> some View {
    Group {
      switch questionType {
      case .single(_, _):
        Image(systemName: "dot.circle")
          .foregroundColor(.blue)
      case .multiple(_, _):
        Image(systemName: "list.bullet")
          .foregroundColor(.green)
      case .text(_):
        Image(systemName: "textformat")
          .foregroundColor(.orange)
      case .info(_, _):
        Image(systemName: "person.crop.circle")
          .foregroundColor(.purple)
      }
    }
    .font(.title3)
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

  /// 日付をフォーマットして返す
  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP_POSIX")
    formatter.dateFormat = "yyyy/M/d H:mm"
    return formatter.string(from: date)
  }
}

// MARK: - Preview
struct AnalysisView_Previews: PreviewProvider {
  static var previews: some View {
    // プレビュー用のダミーアイテム
    let dummyItem = Item(
      timestamp: Date(),
      questionTypes: [
        .single("好きな色は？", ["赤", "青", "緑"]),
        .text("ご意見をお聞かせください"),
      ],
      surveyID: "sample001",
      title: "サンプルアンケート"
    )

    AnalysisView(item: dummyItem)
  }
}

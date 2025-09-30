import SwiftUI

/// 複数選択設問の分析結果を表示するコンポーネント
struct MultipleQuestionAnalysisView: View {
  let questionIndex: Int
  let questionText: String
  let answers: [String]
  let confidenceScores: [Float]
  let images: [Data]
  let options: [String]

  // 要約状態（ViewModel の analysisResults から設定される想定）
  var isSummarizing: Bool = false
  var otherSummary: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 設問ヘッダー
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "list.bullet")
          .foregroundColor(.green)
          .font(.title2)

        VStack(alignment: .leading, spacing: 6) {
          Text("設問 \(questionIndex + 1) (複数選択)")
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
        }

        Spacer()
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("設問文:")
          .font(.subheadline)
          .foregroundColor(.secondary)
        Text(questionText)
          .font(.body)
          .foregroundColor(.primary)
          .fixedSize(horizontal: false, vertical: true)
      }
      // 集計は ViewModel に統一
      let agg = AnalysisViewModel.aggregateMultipleChoice(answers: answers, options: options)
      let otherTexts = agg.otherTexts
      let total = agg.total

      // 円グラフ（回答がある場合のみ表示）
      if total > 0 {
        HStack(alignment: .center, spacing: 16) {
          PieChartView(
            entries: agg.entries.enumerated().map { (i, e) in
              PieChartEntry(
                label: e.label,
                value: e.value,
                color: Color(
                  hue: Double(i) / Double(max(1, agg.entries.count)), saturation: 0.6,
                  brightness: 0.9),
                percent: e.percent
              )
            }
          )
          .frame(width: 140, height: 140)

          Spacer()
        }
      } else {
        Text("選択された回答がありません")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // 有効回答数：円グラフの下、選択肢リストの上に表示
      Text("有効回答: \(total)")
        .font(.caption)
        .foregroundColor(.secondary)

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

      // 回答されている各選択肢をパーセントで表示（未選択の選択肢は除外）
      let percentages = agg.entries
      if !percentages.isEmpty {
        // データ駆動（配列を enumerate して使用）に切り替え、LazyVStack で描画する。
        // 見た目は以前と同じ（Circle + ラベル + パーセント + 件数のレイアウト）を維持する。
        LazyVStack(alignment: .leading, spacing: 6) {
          ForEach(Array(percentages.enumerated()), id: \.0) { pair in
            let idx = pair.0
            let entry = pair.1
            ChoicePercentageRow(
              index: idx, totalItems: percentages.count, label: entry.label, percent: entry.percent,
              count: Int(entry.value))
          }
        }
      }

      // (implementation detail: percentageRow is defined as a private method below)
      VStack(alignment: .leading, spacing: 6) {
        // "その他" の自由記述を抜粋して表示（LLM要約は別処理）
        if !otherTexts.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            // 要約中はインジケータを表示、完了したら要約テキストを表示
            if isSummarizing {
              HStack(spacing: 8) {
                ProgressView()
                  .scaleEffect(0.6, anchor: .center)
                Text("要約を生成中...")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
            } else if let summary = otherSummary {
              VStack(alignment: .leading, spacing: 6) {
                Text("要約:")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                Text(summary)
                  .font(.subheadline)
                  .foregroundColor(.primary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
        }
      }
    }
    .padding()
  }
}

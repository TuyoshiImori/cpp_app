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
        .font(.subheadline)
        .foregroundColor(.secondary)

      // 回答されている各選択肢をパーセントで表示（未選択の選択肢は除外）
      let percentages = agg.entries
      if !percentages.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(percentages.indices, id: \.self) { idx in
            let item = percentages[idx]

            HStack {
              Circle()
                .fill(
                  Color(
                    hue: Double(idx) / Double(max(1, percentages.count)), saturation: 0.6,
                    brightness: 0.9)
                )
                .frame(width: 10, height: 10)
              // 表示フォーマット: 選択肢：xx.x%（n件）
              Text("\(item.label)： \(String(format: "%.1f", item.percent))%（\(Int(item.value))件）")
                .font(.caption)
                .foregroundColor(.primary)
              Spacer()
            }
          }

          // "その他" の自由記述を抜粋して表示（LLM要約は別処理）
          if !otherTexts.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              // 要約中はインジケータを表示、完了したら要約テキストを表示
              if isSummarizing {
                HStack(spacing: 8) {
                  ProgressView()
                    .scaleEffect(0.6, anchor: .center)
                  Text("要約を生成中...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
              } else if let summary = otherSummary {
                VStack(alignment: .leading, spacing: 6) {
                  Text("要約:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                  Text(summary)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
            }
          }
        }
      }
    }
    .padding()
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(12)
  }
}

// 集計ロジックは AnalysisViewModel に移動済み

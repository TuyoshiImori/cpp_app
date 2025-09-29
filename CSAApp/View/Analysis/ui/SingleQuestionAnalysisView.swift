import SwiftUI

/// 選択式設問（単一選択）の分析結果を表示するコンポーネント
struct SingleQuestionAnalysisView: View {
  let questionIndex: Int
  let questionText: String
  let answers: [String]
  let confidenceScores: [Float]
  let images: [Data]  // UIImageの代わりにDataを使用
  let options: [String]
  // 要約状態（ViewModel の analysisResults から設定される想定）
  var isSummarizing: Bool = false
  var otherSummary: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 設問ヘッダー
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "dot.circle")
          .foregroundColor(.blue)
          .font(.title2)

        VStack(alignment: .leading, spacing: 6) {
          Text("設問 \(questionIndex + 1) (単一選択)")
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

      // 集計ロジックは ViewModel に移譲
      let agg = AnalysisViewModel.aggregateSingleChoice(answers: answers, options: options)
      let otherTexts = agg.otherTexts
      let total = agg.total

      // 円グラフ（回答がある場合のみ表示）
      if total > 0 {
        HStack(alignment: .center, spacing: 16) {
          // ViewModel から返された entries を PieChartEntry にマッピング（色はインデックスで割当）
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
              VStack(alignment: .leading, spacing: 2) {
                HStack {
                  Text(item.label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                  Spacer()
                  Text("\(String(format: "%.1f", item.percent))%")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                }
                Text("\(Int(item.value))件")
                  .font(.caption2)
                  .foregroundColor(.secondary)
              }
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
    }
    .padding()
  }
}

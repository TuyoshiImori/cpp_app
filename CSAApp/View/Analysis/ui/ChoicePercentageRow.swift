import SwiftUI

/// 選択肢行を共通化した再利用コンポーネント
/// - index: 選択肢インデックス（色の計算に利用）
/// - totalItems: 全選択肢数（色の分割に利用）
/// - label: 選択肢ラベル
/// - percent: パーセンテージ表示（例: 12.3）
/// - count: 件数
public struct ChoicePercentageRow: View {
  public let index: Int
  public let totalItems: Int
  public let label: String
  public let percent: Double
  public let count: Int

  public init(index: Int, totalItems: Int, label: String, percent: Double, count: Int) {
    self.index = index
    self.totalItems = totalItems
    self.label = label
    self.percent = percent
    self.count = count
  }

  public var body: some View {
    HStack {
      Circle()
        .fill(SliceColor.sliceColor(index: index, total: totalItems))
        .frame(width: 10, height: 10)

      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(label)
            .font(.subheadline)
            .foregroundColor(.primary)
          Spacer()
          Text("\(String(format: "%.1f", percent))%")
            .font(.subheadline)
            .foregroundColor(.primary)
        }
        Text("\(count)件")
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
  }
}

// legend color is provided by `SliceColor` util

import SwiftUI

// 共通円グラフコンポーネント
struct PieChartEntry: Identifiable {
  let id = UUID()
  let label: String
  let value: Double
  let color: Color
  var percent: Double = 0.0

  init(label: String, value: Double, color: Color, percent: Double = 0.0) {
    self.label = label
    self.value = value
    self.color = color
    self.percent = percent
  }
}

struct PieChartView: View {
  let entries: [PieChartEntry]

  init(entries: [PieChartEntry]) {
    self.entries = entries
  }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        if entries.isEmpty {
          Circle()
            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
        } else {
          let total = entries.map { $0.value }.reduce(0, +)
          var current: Double = -90.0
          let slices: [(entry: PieChartEntry, start: Double, end: Double)] = entries.map { entry in
            let degree = (entry.value / max(total, 1)) * 360.0
            let s = current
            let e = current + degree
            current += degree
            return (entry: entry, start: s, end: e)
          }

          ForEach(slices, id: \.entry.id) { slice in
            PieSlice(startAngle: Angle(degrees: slice.start), endAngle: Angle(degrees: slice.end))
              .fill(slice.entry.color)
          }
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
  }
}

private struct PieSlice: Shape {
  let startAngle: Angle
  let endAngle: Angle

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    path.move(to: center)
    path.addArc(
      center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
    path.closeSubpath()
    return path
  }
}

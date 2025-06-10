import SwiftUI

struct QuadOverlay: View {
  let quad: [CGPoint]
  var body: some View {
    GeometryReader { geo in
      Path { path in
        guard quad.count == 4 else { return }
        path.move(to: CGPoint(x: quad[0].x * geo.size.width, y: quad[0].y * geo.size.height))
        path.addLine(to: CGPoint(x: quad[1].x * geo.size.width, y: quad[1].y * geo.size.height))
        path.addLine(to: CGPoint(x: quad[2].x * geo.size.width, y: quad[2].y * geo.size.height))
        path.addLine(to: CGPoint(x: quad[3].x * geo.size.width, y: quad[3].y * geo.size.height))
        path.closeSubpath()
      }
      .stroke(Color.green, lineWidth: 3)
    }
    .allowsHitTesting(false)
  }
}

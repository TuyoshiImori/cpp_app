import SwiftUI

struct QuadOverlay: View {
  let feature: RectangleFeature
  var body: some View {
    GeometryReader { geo in
      Path { path in
        path.move(to: feature.topLeft)
        path.addLine(to: feature.topRight)
        path.addLine(to: feature.bottomRight)
        path.addLine(to: feature.bottomLeft)
        path.closeSubpath()
      }
      .stroke(Color.green, lineWidth: 3)
    }
    .allowsHitTesting(false)
  }
}

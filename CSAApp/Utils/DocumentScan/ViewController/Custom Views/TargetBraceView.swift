import SwiftUI

struct TargetBraceView: View {
  var color: Color = .red

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height
      let braceLength = width * 0.15
      let lineWidth = 2 * UIScreen.main.scale

      Path { path in
        // Top Left
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: braceLength, y: 0))
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 0, y: braceLength))

        // Top Right
        path.move(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width - braceLength, y: 0))
        path.move(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: braceLength))

        // Bottom Left
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: braceLength, y: height))
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: height - braceLength))

        // Bottom Right
        path.move(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width - braceLength, y: height))
        path.move(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: height - braceLength))
      }
      .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .square, lineJoin: .bevel))
    }
    .background(Color.clear)
    .allowsHitTesting(false)
  }
}

// プレビュー
#Preview {
  TargetBraceView()
    .frame(width: 200, height: 200)
    .background(Color.black)
}

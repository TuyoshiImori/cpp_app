import SwiftUI

struct FocusRectView: View {
  var color: Color = .red
  var lineWidth: CGFloat = 1

  var body: some View {
    GeometryReader { geometry in
      let rect = geometry.frame(in: .local)
      let lineLength = rect.width * 0.1

      Path { path in
        // 四辺の中央から内側へ短い線を描画
        // 上
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: lineLength))
        // 右
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - lineLength, y: rect.midY))
        // 下
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - lineLength))
        // 左
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: lineLength, y: rect.midY))
      }
      .stroke(color, lineWidth: lineWidth)
    }
    .background(Color.clear)
    .allowsHitTesting(false)
  }
}

// プレビュー
#Preview {
  FocusRectView()
    .frame(width: 200, height: 200)
    .background(Color.black)
}

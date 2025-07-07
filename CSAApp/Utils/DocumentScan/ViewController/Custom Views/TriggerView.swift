import SwiftUI

struct TriggerView: View {
  var isHighlighted: Bool = false

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let gap = width * (isHighlighted ? 0.06 : 0.03)
      let thickness = 0.09 * width

      ZStack {
        // 外側の円
        Circle()
          .stroke(Color.white, lineWidth: thickness)
          .frame(width: width - thickness, height: width - thickness)
        // 内側の円
        Circle()
          .fill(Color.white)
          .frame(width: width - 2 * (gap + thickness), height: width - 2 * (gap + thickness))
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .background(Color.clear)
    .allowsHitTesting(false)
  }
}

// プレビュー
#Preview {
  VStack(spacing: 40) {
    TriggerView(isHighlighted: false)
      .frame(width: 100, height: 100)
      .background(Color.black)
    TriggerView(isHighlighted: true)
      .frame(width: 100, height: 100)
      .background(Color.black)
  }
}

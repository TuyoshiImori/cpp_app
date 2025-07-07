import SwiftUI

protocol TorchPickerViewDelegate: AnyObject {
  var lastTorchLevel: Float { get }
  var hasTorch: Bool { get }
  func toggleTorch()
  func didPickTorchLevel(_ level: Float)
}

struct TorchPickerView: View {
  @Binding var torchLevel: Float
  var hasTorch: Bool
  var onLevelChange: (Float) -> Void
  var onDismiss: () -> Void

  private let levels: [Float] = [1.0, 0.75, 0.5, 0.25, 0.0]

  var body: some View {
    VStack(spacing: 2) {
      ForEach(levels, id: \.self) { level in
        Rectangle()
          .fill(self.torchLevel >= level ? Color.gray.opacity(0.45) : Color.white.opacity(0.65))
          .frame(height: 32)
          .onTapGesture {
            self.torchLevel = level
            self.onLevelChange(level)
          }
      }
    }
    .frame(width: 60, height: 160)
    .background(
      VisualEffectBlur(blurStyle: .systemMaterialLight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    )
    .cornerRadius(16)
    .shadow(radius: 8)
    .onTapGesture {
      self.onDismiss()
    }
  }
}

// VisualEffectBlurはiOS15以降なら標準でOK
struct VisualEffectBlur: UIViewRepresentable {
  var blurStyle: UIBlurEffect.Style

  func makeUIView(context: Context) -> UIVisualEffectView {
    UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
  }

  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// プレビュー
struct TorchPickerView_Previews: PreviewProvider {
  static var previews: some View {
    TorchPickerView(
      torchLevel: .constant(0.5),
      hasTorch: true,
      onLevelChange: { _ in },
      onDismiss: {}
    )
  }
}

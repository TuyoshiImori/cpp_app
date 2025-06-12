import UIKit

final class TargetBraceView: UIView {
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let braceRect = rect.insetBy(dx: 8, dy: 8)
    context.setStrokeColor(UIColor.red.cgColor)
    context.setLineWidth(3)
    context.stroke(braceRect)
  }
}

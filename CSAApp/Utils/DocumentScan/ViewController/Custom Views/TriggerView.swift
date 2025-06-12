import UIKit

final class TriggerView: UIView {
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let circleRect = rect.insetBy(dx: 6, dy: 6)
    context.setStrokeColor(UIColor.white.cgColor)
    context.setLineWidth(4)
    context.strokeEllipse(in: circleRect)
  }
}

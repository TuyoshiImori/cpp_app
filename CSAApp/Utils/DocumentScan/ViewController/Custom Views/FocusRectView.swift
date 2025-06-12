import UIKit

final class FocusRectView: UIView {
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let insetRect = rect.insetBy(dx: 4, dy: 4)
    context.setStrokeColor(UIColor.green.cgColor)
    context.setLineWidth(2)
    context.stroke(insetRect)
  }
}

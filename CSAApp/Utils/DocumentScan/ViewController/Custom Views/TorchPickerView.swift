import UIKit

final class TorchPickerView: UIView {
  var isOn: Bool = false {
    didSet { setNeedsDisplay() }
  }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let color = isOn ? UIColor.yellow : UIColor.gray
    context.setFillColor(color.cgColor)
    context.fillEllipse(in: rect.insetBy(dx: 8, dy: 8))
  }
}

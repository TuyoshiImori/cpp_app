import CoreGraphics
import ImageIO
import UIKit

extension CGImagePropertyOrientation {
  init(_ uiOrientation: UIImage.Orientation) {
    switch uiOrientation {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}

extension CGPoint {
  func yAxisInverted(_ maxY: CGFloat) -> CGPoint {
    CGPoint(x: x, y: maxY - y)
  }
  func shifted(by shift: CGPoint) -> CGPoint {
    CGPoint(x: x + shift.x, y: y + shift.y)
  }
  func scaled(by scale: CGVector) -> CGPoint {
    CGPoint(x: x * scale.dx, y: y * scale.dy)
  }
  func distance(to point: CGPoint) -> CGFloat {
    hypot(self.x - point.x, self.y - point.y)
  }
}

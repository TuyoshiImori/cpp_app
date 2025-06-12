import CoreGraphics

extension CGPoint {
  static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }
  static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }
  static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
    CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
  }
  static func += (lhs: inout CGPoint, rhs: CGPoint) {
    lhs = lhs + rhs
  }
}

// CGPointの絶対値和
func abs(_ point: CGPoint) -> CGFloat {
  abs(point.x) + abs(point.y)
}

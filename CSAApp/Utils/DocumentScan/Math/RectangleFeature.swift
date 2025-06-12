import CoreGraphics
import UIKit

public struct RectangleFeature {
  let topLeft: CGPoint
  let topRight: CGPoint
  let bottomLeft: CGPoint
  let bottomRight: CGPoint

  // 通常のイニシャライザ
  public init(
    topLeft: CGPoint = .zero,
    topRight: CGPoint = .zero,
    bottomLeft: CGPoint = .zero,
    bottomRight: CGPoint = .zero
  ) {
    self.topLeft = topLeft
    self.topRight = topRight
    self.bottomLeft = bottomLeft
    self.bottomRight = bottomRight
  }

  // CIRectangleFeatureから初期化
  public init(_ feature: CIRectangleFeature) {
    self.topLeft = feature.topLeft
    self.topRight = feature.topRight
    self.bottomLeft = feature.bottomLeft
    self.bottomRight = feature.bottomRight
  }

  // UIBezierPath化
  var bezierPath: UIBezierPath {
    let path = UIBezierPath()
    path.move(to: topLeft)
    path.addLine(to: topRight)
    path.addLine(to: bottomRight)
    path.addLine(to: bottomLeft)
    path.close()
    return path
  }
}

extension RectangleFeature {
  func smoothed(with previous: inout [RectangleFeature]) -> RectangleFeature {
    let allFeatures = [self] + previous
    let smoothed = allFeatures.average
    previous = Array(allFeatures.prefix(10))
    return smoothed
  }

  func normalized(source: CGSize, target: CGSize) -> RectangleFeature {
    // UIView.ContentMode.aspectFillのように、sourceを正規化
    let normalizedSource = CGSize(
      width: source.height * target.aspectRatio,
      height: source.height)
    let xShift = (normalizedSource.width - source.width) / 2
    let yShift = (normalizedSource.height - source.height) / 2

    let distortion = CGVector(
      dx: target.width / normalizedSource.width,
      dy: target.height / normalizedSource.height)

    func normalize(_ point: CGPoint) -> CGPoint {
      point
        .yAxisInverted(source.height)
        .shifted(by: CGPoint(x: xShift, y: yShift))
        .distorted(by: distortion)
    }

    return RectangleFeature(
      topLeft: normalize(topLeft),
      topRight: normalize(topRight),
      bottomLeft: normalize(bottomLeft),
      bottomRight: normalize(bottomRight)
    )
  }

  func difference(to: RectangleFeature) -> CGFloat {
    abs(to.topLeft - topLeft) + abs(to.topRight - topRight) + abs(to.bottomLeft - bottomLeft)
      + abs(to.bottomRight - bottomRight)
  }

  /// This isn't the real area, but enables correct comparison
  private var areaQualifier: CGFloat {
    let diagonalToLeft = (topRight - bottomLeft)
    let diagonalToRight = (topLeft - bottomRight)
    let phi =
      (diagonalToLeft.x * diagonalToRight.x + diagonalToLeft.y * diagonalToRight.y)
      / (diagonalToLeft.length * diagonalToRight.length)
    return sqrt(1 - phi * phi) * diagonalToLeft.length * diagonalToRight.length
  }
}

extension RectangleFeature: Comparable {
  public static func < (lhs: RectangleFeature, rhs: RectangleFeature) -> Bool {
    lhs.areaQualifier < rhs.areaQualifier
  }
}

extension CGSize {
  fileprivate var aspectRatio: CGFloat {
    width / height
  }
}

extension CGPoint {
  fileprivate func distorted(by distortion: CGVector) -> CGPoint {
    CGPoint(x: x * distortion.dx, y: y * distortion.dy)
  }

  fileprivate func yAxisInverted(_ maxY: CGFloat) -> CGPoint {
    CGPoint(x: x, y: maxY - y)
  }

  fileprivate func shifted(by shiftAmount: CGPoint) -> CGPoint {
    CGPoint(x: x + shiftAmount.x, y: y + shiftAmount.y)
  }

  fileprivate var length: CGFloat {
    sqrt(x * x + y * y)
  }
}

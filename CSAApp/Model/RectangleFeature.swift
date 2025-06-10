import CoreGraphics
import Vision

public struct RectangleFeature {
  public let topLeft: CGPoint
  public let topRight: CGPoint
  public let bottomRight: CGPoint
  public let bottomLeft: CGPoint

  public init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
    self.topLeft = topLeft
    self.topRight = topRight
    self.bottomRight = bottomRight
    self.bottomLeft = bottomLeft
  }

  public static func average(_ features: [RectangleFeature]) -> RectangleFeature {
    let count = CGFloat(features.count)
    func avg(_ points: [CGPoint]) -> CGPoint {
      CGPoint(
        x: points.map { $0.x }.reduce(0, +) / count,
        y: points.map { $0.y }.reduce(0, +) / count
      )
    }
    return RectangleFeature(
      topLeft: avg(features.map { $0.topLeft }),
      topRight: avg(features.map { $0.topRight }),
      bottomRight: avg(features.map { $0.bottomRight }),
      bottomLeft: avg(features.map { $0.bottomLeft })
    )
  }

  public static func jitter(_ features: [RectangleFeature]) -> CGFloat {
    guard features.count > 1 else { return 0 }
    let avg = average(features)
    func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
      hypot(a.x - b.x, a.y - b.y)
    }
    let dists = features.map {
      dist($0.topLeft, avg.topLeft) + dist($0.topRight, avg.topRight)
        + dist($0.bottomRight, avg.bottomRight) + dist($0.bottomLeft, avg.bottomLeft)
    }
    return dists.reduce(0, +) / CGFloat(dists.count)
  }

  public func boundingRect() -> CGRect {
    let xs = [topLeft.x, topRight.x, bottomRight.x, bottomLeft.x]
    let ys = [topLeft.y, topRight.y, bottomRight.y, bottomLeft.y]
    let minX = xs.min() ?? 0
    let maxX = xs.max() ?? 0
    let minY = ys.min() ?? 0
    let maxY = ys.max() ?? 0
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  public static func from(observation: VNRectangleObservation, width: CGFloat, height: CGFloat)
    -> RectangleFeature
  {
    RectangleFeature(
      topLeft: CGPoint(x: observation.topLeft.x * width, y: (1 - observation.topLeft.y) * height),
      topRight: CGPoint(
        x: observation.topRight.x * width, y: (1 - observation.topRight.y) * height),
      bottomRight: CGPoint(
        x: observation.bottomRight.x * width, y: (1 - observation.bottomRight.y) * height),
      bottomLeft: CGPoint(
        x: observation.bottomLeft.x * width, y: (1 - observation.bottomLeft.y) * height)
    )
  }
}

public func medianRectangleFeature(_ features: [RectangleFeature]) -> RectangleFeature {
  func median(_ values: [CGFloat]) -> CGFloat {
    let sorted = values.sorted()
    let mid = sorted.count / 2
    return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
  }
  return RectangleFeature(
    topLeft: CGPoint(
      x: median(features.map { $0.topLeft.x }), y: median(features.map { $0.topLeft.y })),
    topRight: CGPoint(
      x: median(features.map { $0.topRight.x }), y: median(features.map { $0.topRight.y })),
    bottomRight: CGPoint(
      x: median(features.map { $0.bottomRight.x }), y: median(features.map { $0.bottomRight.y })),
    bottomLeft: CGPoint(
      x: median(features.map { $0.bottomLeft.x }), y: median(features.map { $0.bottomLeft.y }))
  )
}

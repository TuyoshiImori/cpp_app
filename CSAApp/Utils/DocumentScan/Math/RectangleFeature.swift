import CoreGraphics
import Vision

public struct RectangleFeature: Equatable {
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

  /// VNRectangleObservationからRectangleFeatureを生成
  public static func from(observation: VNRectangleObservation, width: CGFloat, height: CGFloat)
    -> RectangleFeature
  {
    func convert(_ point: CGPoint) -> CGPoint {
      CGPoint(x: point.x * width, y: (1 - point.y) * height)
    }
    return RectangleFeature(
      topLeft: convert(observation.topLeft),
      topRight: convert(observation.topRight),
      bottomRight: convert(observation.bottomRight),
      bottomLeft: convert(observation.bottomLeft)
    )
  }

  /// RectangleFeature配列の平均値
  public static func average(_ features: [RectangleFeature]) -> RectangleFeature {
    guard !features.isEmpty else {
      return RectangleFeature(
        topLeft: .zero, topRight: .zero, bottomRight: .zero, bottomLeft: .zero)
    }
    let count = CGFloat(features.count)
    func avg(_ points: [CGPoint]) -> CGPoint {
      points.reduce(.zero, +) / count
    }
    return RectangleFeature(
      topLeft: avg(features.map { $0.topLeft }),
      topRight: avg(features.map { $0.topRight }),
      bottomRight: avg(features.map { $0.bottomRight }),
      bottomLeft: avg(features.map { $0.bottomLeft })
    )
  }

  /// RectangleFeature配列のジッター（ばらつき）を計算
  public static func jitter(_ features: [RectangleFeature]) -> CGFloat {
    guard features.count > 1 else { return 0 }
    let avg = average(features)
    let diffs = features.map {
      abs($0.topLeft - avg.topLeft) + abs($0.topRight - avg.topRight)
        + abs($0.bottomRight - avg.bottomRight) + abs($0.bottomLeft - avg.bottomLeft)
    }
    return diffs.reduce(0, +) / CGFloat(diffs.count)
  }
}

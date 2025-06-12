import CoreGraphics

extension Array where Element == RectangleFeature {
  /// 全要素のjitter（平均との差の合計）を返す
  var jitter: CGFloat {
    guard !isEmpty else { return 0 }
    let averageElement = average
    let diffs = map { $0.difference(to: averageElement) }
    return diffs.reduce(0, +)
  }

  /// RectangleFeatureの平均値
  var average: RectangleFeature {
    guard !isEmpty else { return RectangleFeature() }
    return reduce(RectangleFeature(), +) / CGFloat(count)
  }
}

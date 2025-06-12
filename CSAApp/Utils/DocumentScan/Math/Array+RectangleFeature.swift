import Foundation

extension Array where Element == RectangleFeature {
  /// 配列の中央値RectangleFeatureを返す
  func medianFeature() -> RectangleFeature? {
    guard !isEmpty else { return nil }
    func median(_ values: [CGFloat]) -> CGFloat {
      let sorted = values.sorted()
      let count = sorted.count
      if count % 2 == 0 {
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
      } else {
        return sorted[count / 2]
      }
    }
    return RectangleFeature(
      topLeft: CGPoint(
        x: median(map { $0.topLeft.x }),
        y: median(map { $0.topLeft.y })
      ),
      topRight: CGPoint(
        x: median(map { $0.topRight.x }),
        y: median(map { $0.topRight.y })
      ),
      bottomRight: CGPoint(
        x: median(map { $0.bottomRight.x }),
        y: median(map { $0.bottomRight.y })
      ),
      bottomLeft: CGPoint(
        x: median(map { $0.bottomLeft.x }),
        y: median(map { $0.bottomLeft.y })
      )
    )
  }
}

import UIKit
import Vision

extension UIImage {
  /// 画像をリサイズ→グレースケール→鮮鋭化→二値化→モルフォロジー処理（OpenCVで実装）→円検出し、
  /// グレースケール画像と円の中心座標（画像内座標）を返す
  func detectCirclesWithVisionSync() -> (UIImage, [CGPoint]) {
    // OpenCVWrapper経由で前処理済み画像を取得
    guard let processedImage = OpenCVWrapper.processImage(self) else { return (self, []) }
    // Vision用にCGImage化
    guard let cgimg = processedImage.cgImage else { return (self, []) }
    // リサイズ後のサイズを取得（OpenCVWrapperでリサイズしている場合はそちらに合わせて）
    let newSize = CGSize(width: processedImage.size.width, height: processedImage.size.height)
    // --- 以降はVisionで円検出（既存ロジックのまま） ---
    var circleCenters: [CGPoint] = []
    let semaphore = DispatchSemaphore(value: 0)
    let request = VNDetectContoursRequest()
    request.contrastAdjustment = 2.0
    request.detectsDarkOnLight = true
    request.maximumImageDimension = Int(newSize.width)
    let handler = VNImageRequestHandler(cgImage: cgimg, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      defer { semaphore.signal() }
      do {
        try handler.perform([request])
        guard let observation = request.results?.first as? VNContoursObservation else { return }
        func collectContours(_ contour: VNContour) -> [VNContour] {
          return [contour] + contour.childContours.flatMap { collectContours($0) }
        }
        let allContours = observation.topLevelContours.flatMap { collectContours($0) }
        for contour in allContours {
          let points = contour.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
          guard points.count >= 6 else { continue }
          let isClosed =
            hypot(points.first!.x - points.last!.x, points.first!.y - points.last!.y) < 0.08
          guard isClosed else { continue }
          var area: Double = 0
          var perimeter: Double = 0
          if #available(iOS 15.0, *) {
            try? VNGeometryUtils.calculateArea(&area, for: contour, orientedArea: false)
            try? VNGeometryUtils.calculatePerimeter(&perimeter, for: contour)
          } else {
            area =
              abs(
                zip(points, points.dropFirst() + [points.first!]).reduce(0) { sum, pair in
                  let (p1, p2) = pair
                  return sum + Double(p1.x * p2.y - p2.x * p1.y)
                }) / 2.0
            perimeter = zip(points, points.dropFirst() + [points.first!]).reduce(0) { sum, pair in
              let (p1, p2) = pair
              return sum + Double(hypot(p1.x - p2.x, p1.y - p2.y))
            }
          }
          let circularity = (perimeter > 0) ? (4 * Double.pi * area) / (perimeter * perimeter) : 0
          guard circularity > 0.85 else { continue }
          let center = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
          let centerNorm = CGPoint(
            x: center.x / CGFloat(points.count), y: center.y / CGFloat(points.count))
          let imgSize = CGSize(width: newSize.width, height: newSize.height)
          let cgpt = CGPoint(
            x: centerNorm.x * imgSize.width, y: (1.0 - centerNorm.y) * imgSize.height)
          circleCenters.append(cgpt)
        }
      } catch {
        // 無視
      }
    }
    semaphore.wait()
    // グレースケール画像を返す
    return (processedImage, circleCenters)
  }
}

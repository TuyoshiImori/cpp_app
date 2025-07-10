import UIKit
import Vision

extension UIImage {
  /// 画像をリサイズ→グレースケール→鮮鋭化→二値化→モルフォロジー処理→円検出し、
  /// グレースケール画像と円の中心座標（画像内座標）を返す
  func detectCirclesWithVisionSync() -> (UIImage, [CGPoint]) {
    // 1. 画像をリサイズ（例: 最大幅1024px）
    let targetWidth: CGFloat = 1024
    let scale = targetWidth / max(self.size.width, self.size.height)
    let newSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    self.draw(in: CGRect(origin: .zero, size: newSize))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
    UIGraphicsEndImageContext()

    // 2. グレースケール化
    guard let ciImage = CIImage(image: resizedImage) else {
      return (self, [])
    }
    let gray = ciImage.applyingFilter(
      "CIColorMatrix",
      parameters: [
        "inputRVector": CIVector(x: 0.298912, y: 0.586611, z: 0.114478, w: 0),
        "inputGVector": CIVector(x: 0.298912, y: 0.586611, z: 0.114478, w: 0),
        "inputBVector": CIVector(x: 0.298912, y: 0.586611, z: 0.114478, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
      ])
    // 3. 鮮鋭化（アンシャープマスク）
    let sharp = gray.applyingFilter(
      "CIUnsharpMask",
      parameters: ["inputRadius": 5.0, "inputIntensity": 2.0])
    // 4. 二値化（明度クラップ）
    let clampMin = CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
    let clampMax = CIVector(x: 0.8, y: 0.8, z: 0.8, w: 1.0)
    let clamped = sharp.applyingFilter(
      "CIColorClamp",
      parameters: ["inputMinComponents": clampMin, "inputMaxComponents": clampMax])
    // 5. モルフォロジー処理（膨張→収縮でノイズ除去）
    let morphed =
      clamped
      .applyingFilter(
        "CIMorphologyRectangleMaximum", parameters: ["inputWidth": 3, "inputHeight": 3]
      )
      .applyingFilter(
        "CIMorphologyRectangleMinimum", parameters: ["inputWidth": 3, "inputHeight": 3])
    // 6. CGImage化
    let context = CIContext()
    guard let cgimg = context.createCGImage(morphed, from: morphed.extent) else {
      return (self, [])
    }
    // 7. Visionで輪郭検出（同期）
    var circleCenters: [CGPoint] = []
    let semaphore = DispatchSemaphore(value: 0)
    let request = VNDetectContoursRequest()
    request.contrastAdjustment = 2.0
    request.detectsDarkOnLight = true
    request.maximumImageDimension = Int(targetWidth)
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
    if let cgImage = context.createCGImage(gray, from: gray.extent) {
      return (UIImage(cgImage: cgImage), circleCenters)
    } else {
      return (self, circleCenters)
    }
  }
}

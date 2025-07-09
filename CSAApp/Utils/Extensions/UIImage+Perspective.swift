import UIKit

extension UIImage {
  /// グレースケール画像のみ返す（OCR用に最適化）
  func toGrayscaleOnly() -> UIImage? {
    guard let ciImage = CIImage(image: self) else { return nil }
    let colorMatrixFilter = CIFilter(name: "CIColorMatrix")!
    colorMatrixFilter.setValue(ciImage, forKey: kCIInputImageKey)
    let grayScaleVector = CIVector(x: 0.298912, y: 0.586611, z: 0.114478, w: 0)
    colorMatrixFilter.setValue(grayScaleVector, forKey: "inputRVector")
    colorMatrixFilter.setValue(grayScaleVector, forKey: "inputGVector")
    colorMatrixFilter.setValue(grayScaleVector, forKey: "inputBVector")
    colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
    guard let grayScaleImage = colorMatrixFilter.outputImage else { return nil }
    let context = CIContext()
    if let cgImage = context.createCGImage(grayScaleImage, from: grayScaleImage.extent) {
      return UIImage(cgImage: cgImage)
    }
    return nil
  }
}

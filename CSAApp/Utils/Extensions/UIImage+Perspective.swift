import CoreImage
import UIKit

extension UIImage {
  func perspectiveCorrected(to quad: RectangleFeature) -> UIImage? {
    guard let ciImage = CIImage(image: self) else { return nil }
    let filter = CIFilter(name: "CIPerspectiveCorrection")!
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgPoint: quad.topLeft), forKey: "inputTopLeft")
    filter.setValue(CIVector(cgPoint: quad.topRight), forKey: "inputTopRight")
    filter.setValue(CIVector(cgPoint: quad.bottomRight), forKey: "inputBottomRight")
    filter.setValue(CIVector(cgPoint: quad.bottomLeft), forKey: "inputBottomLeft")
    guard let output = filter.outputImage else { return nil }
    let context = CIContext()
    if let cgimg = context.createCGImage(output, from: output.extent) {
      return UIImage(cgImage: cgimg)
    }
    return nil
  }
}

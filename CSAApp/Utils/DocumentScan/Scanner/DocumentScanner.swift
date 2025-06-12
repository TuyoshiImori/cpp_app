import AVFoundation
import UIKit

public protocol DocumentScanner: AnyObject {
  var desiredJitter: CGFloat { get set }
  var featuresRequired: Int { get set }
  var previewLayer: CALayer { get }
  var progress: Progress { get }

  func captureImage(in bounds: RectangleFeature?, completion: @escaping (UIImage) -> Void)
  func start()
  func pause()
  func stop()
}

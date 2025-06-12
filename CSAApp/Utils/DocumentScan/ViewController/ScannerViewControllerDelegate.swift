import UIKit

protocol ScannerViewControllerDelegate: AnyObject {
  func scanner(_ scanner: ScannerViewController, didCaptureImage image: UIImage)
  func scannerDidCancel(_ scanner: ScannerViewController)
}

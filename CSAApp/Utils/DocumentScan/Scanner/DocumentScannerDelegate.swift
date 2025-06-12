import Foundation

protocol DocumentScannerDelegate: AnyObject {
  func documentScanner(_ scanner: DocumentScanner, didDetectRectangle feature: RectangleFeature)
  func documentScanner(_ scanner: DocumentScanner, didFailWithError error: Error)
}

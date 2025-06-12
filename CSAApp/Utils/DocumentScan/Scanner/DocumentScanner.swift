import UIKit
import Vision

// ここからプロトコル定義を削除

final class DocumentScanner {
  weak var delegate: DocumentScannerDelegate?

  private let sequenceHandler = VNSequenceRequestHandler()

  func detectRectangle(in image: CGImage) {
    let request = VNDetectRectanglesRequest { [weak self] request, error in
      if let error = error {
        self?.delegate?.documentScanner(self!, didFailWithError: error)
        return
      }
      guard let observation = request.results?.first as? VNRectangleObservation else { return }
      let feature = RectangleFeature.from(
        observation: observation,
        width: CGFloat(image.width),
        height: CGFloat(image.height)
      )
      self?.delegate?.documentScanner(self!, didDetectRectangle: feature)
    }
    request.minimumConfidence = 0.7
    request.minimumAspectRatio = 0.3
    do {
      try sequenceHandler.perform([request], on: image)
    } catch {
      delegate?.documentScanner(self, didFailWithError: error)
    }
  }
}

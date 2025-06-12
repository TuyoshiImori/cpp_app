import CoreImage
import UIKit

/// スキャナーのデリゲート（コールバックは常にメインキューで呼ばれる）
public protocol DocumentScannerDelegate: AnyObject {
  /// スキャナーが画像を取得したときに呼ばれる
  func didCapture(image: UIImage)

  /// プレビュー用の矩形情報と画像を通知
  func didRecognize(feature: RectangleFeature?, in image: CIImage)
}

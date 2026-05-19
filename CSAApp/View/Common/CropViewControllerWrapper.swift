import CropViewController
import SwiftUI

struct CropViewControllerWrapper: UIViewControllerRepresentable {
  let image: UIImage
  let onCrop: (UIImage) -> Void
  let onCancel: () -> Void

  func makeUIViewController(context: Context) -> CropViewController {
    let cropVC = CropViewController(image: image)
    cropVC.delegate = context.coordinator
    cropVC.aspectRatioLockEnabled = false
    cropVC.resetAspectRatioEnabled = true
    cropVC.rotateButtonsHidden = true
    return cropVC
  }

  func updateUIViewController(_ uiViewController: CropViewController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onCrop: onCrop, onCancel: onCancel)
  }

  final class Coordinator: NSObject, CropViewControllerDelegate {
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    init(onCrop: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
      self.onCrop = onCrop
      self.onCancel = onCancel
    }

    func cropViewController(
      _ cropViewController: CropViewController,
      didCropToImage image: UIImage,
      withRect cropRect: CGRect,
      angle: Int
    ) {
      onCrop(image)
    }

    func cropViewController(
      _ cropViewController: CropViewController,
      didFinishCancelled cancelled: Bool
    ) {
      if cancelled { onCancel() }
    }
  }
}

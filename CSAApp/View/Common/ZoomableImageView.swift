import SwiftUI
import UIKit

/// ピンチ・ダブルタップでズーム可能な画像ビュー（UIScrollView ベース）
struct ZoomableImageView: UIViewRepresentable {
  let image: UIImage

  func makeUIView(context: Context) -> UIScrollView {
    let scrollView = UIScrollView()
    scrollView.delegate = context.coordinator
    scrollView.minimumZoomScale = 1.0
    scrollView.maximumZoomScale = 5.0
    scrollView.bouncesZoom = true
    scrollView.backgroundColor = .clear
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false

    let imageView = UIImageView(image: image)
    imageView.contentMode = .scaleAspectFit
    imageView.isUserInteractionEnabled = true
    scrollView.addSubview(imageView)
    context.coordinator.imageView = imageView

    let doubleTap = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleDoubleTap(_:))
    )
    doubleTap.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(doubleTap)

    return scrollView
  }

  func updateUIView(_ scrollView: UIScrollView, context: Context) {
    context.coordinator.image = image
    context.coordinator.imageView?.image = image
    context.coordinator.layoutImageView(in: scrollView)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(image: image)
  }

  final class Coordinator: NSObject, UIScrollViewDelegate {
    var image: UIImage
    weak var imageView: UIImageView?

    init(image: UIImage) {
      self.image = image
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      guard let imageView = imageView else { return }
      let size = scrollView.bounds.size
      let x = max(0, (size.width - imageView.frame.width) / 2)
      let y = max(0, (size.height - imageView.frame.height) / 2)
      scrollView.contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }

    func layoutImageView(in scrollView: UIScrollView) {
      guard let imageView = imageView else { return }
      let size = scrollView.bounds.size
      guard size.width > 0, size.height > 0 else {
        DispatchQueue.main.async { [weak self, weak scrollView] in
          guard let self, let scrollView else { return }
          self.layoutImageView(in: scrollView)
        }
        return
      }
      let imageSize = image.size
      let scale = min(size.width / imageSize.width, size.height / imageSize.height)
      let w = imageSize.width * scale
      let h = imageSize.height * scale
      imageView.frame = CGRect(
        x: (size.width - w) / 2,
        y: (size.height - h) / 2,
        width: w,
        height: h
      )
      scrollView.contentSize = size
      scrollView.zoomScale = 1.0
    }

    @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
      guard let scrollView = gesture.view as? UIScrollView else { return }
      if scrollView.zoomScale > scrollView.minimumZoomScale {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
      } else {
        let point = gesture.location(in: imageView)
        let w = scrollView.bounds.width / 3
        let h = scrollView.bounds.height / 3
        scrollView.zoom(
          to: CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h),
          animated: true
        )
      }
    }
  }
}

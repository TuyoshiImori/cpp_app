import SwiftUI
import UIKit

final class ForceTouchGestureRecognizer: UIGestureRecognizer {
  private(set) var force: CGFloat = 0.0
  var maximumForce: CGFloat = 4.0

  convenience init() {
    self.init(target: nil, action: nil)
  }

  override init(target: Any?, action: Selector?) {
    super.init(target: target, action: action)
    cancelsTouchesInView = false
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesBegan(touches, with: event)
    normalizeForceAndFireEvent(.began, touches: touches)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesMoved(touches, with: event)
    normalizeForceAndFireEvent(.changed, touches: touches)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesEnded(touches, with: event)
    normalizeForceAndFireEvent(.ended, touches: touches)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesCancelled(touches, with: event)
    normalizeForceAndFireEvent(.cancelled, touches: touches)
  }

  private func normalizeForceAndFireEvent(_ state: UIGestureRecognizer.State, touches: Set<UITouch>)
  {
    guard let firstTouch = touches.first else { return }
    maximumForce = min(firstTouch.maximumPossibleForce, maximumForce)
    force = firstTouch.force / maximumForce
    self.state = state
  }

  override func reset() {
    super.reset()
    force = 0.0
  }
}

// SwiftUIで使うためのラッパー
struct ForceTouchGestureView<Content: View>: UIViewRepresentable {
  var minimumForce: CGFloat = 0.5
  var onForceChanged: (CGFloat) -> Void
  var content: () -> Content

  func makeCoordinator() -> Coordinator {
    Coordinator(onForceChanged: onForceChanged)
  }

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let recognizer = ForceTouchGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.handleForceTouch(_:)))
    view.addGestureRecognizer(recognizer)

    // SwiftUIのViewをUIViewに埋め込む
    let hosting = UIHostingController(rootView: content())
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hosting.view)
    NSLayoutConstraint.activate([
      hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    // 特に何もしない
  }

  class Coordinator: NSObject {
    var onForceChanged: (CGFloat) -> Void

    init(onForceChanged: @escaping (CGFloat) -> Void) {
      self.onForceChanged = onForceChanged
    }

    @objc func handleForceTouch(_ recognizer: ForceTouchGestureRecognizer) {
      onForceChanged(recognizer.force)
    }
  }
}

// プレビュー例
#Preview {
  ForceTouchGestureView(
    minimumForce: 0.5,
    onForceChanged: { force in
      print("Force: \(force)")
    }
  ) {
    Circle()
      .fill(Color.blue)
      .frame(width: 100, height: 100)
  }
}

import SwiftUI
import UIKit

// import YesWeScan ← Swift Packageの場合のみ必要

public struct CameraView: View {
  @Binding public var image: UIImage?
  @Environment(\.dismiss) private var dismiss
  @State private var isPresentedScanner = false
  @State private var isManualMode = true

  public init(image: Binding<UIImage?>) {
    self._image = image
  }

  public var body: some View {
    VStack {
      HStack {
        Button(action: { dismiss() }) {
          Image(systemName: "chevron.left")
            .font(.system(size: 24))
            .padding(.leading, 16)
            .padding(.vertical, 8)
        }
        Spacer()
        Button(action: { isManualMode.toggle() }) {
          Text(isManualMode ? "手動" : "自動")
            .foregroundColor(.white)
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .cornerRadius(16)
        }
      }
      .frame(height: 60)
      .frame(maxWidth: .infinity)
      .background(Color.black.opacity(0.5))
      .padding(.top, getSafeAreaTop())

      Spacer()

      Button("スキャン開始") {
        isPresentedScanner = true
      }
      .font(.title)
      .padding()
    }
    .background(Color.black.ignoresSafeArea())
    .fullScreenCover(isPresented: $isPresentedScanner) {
      ScannerViewControllerWrapper(
        image: $image,
        isManualMode: isManualMode,
        onDismiss: { isPresentedScanner = false }
      )
      .ignoresSafeArea()
    }
  }
}

struct ScannerViewControllerWrapper: UIViewControllerRepresentable {
  @Binding var image: UIImage?
  var isManualMode: Bool
  var onDismiss: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIViewController(context: Context) -> UIViewController {
    var config: ScannerViewController.ScannerConfig = [.targetBraces, .torch, .progressBar]
    if isManualMode {
      config.insert(.manualCapture)
    }
    let scannerVC = ScannerViewController(config: config)
    scannerVC.delegate = context.coordinator
    scannerVC.previewColor = .green
    scannerVC.braceColor = .red
    return scannerVC
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    // 必要に応じて設定を反映
  }

  class Coordinator: NSObject, ScannerViewControllerDelegate {
    let parent: ScannerViewControllerWrapper

    init(parent: ScannerViewControllerWrapper) {
      self.parent = parent
    }

    func scanner(_ scanner: ScannerViewController, didCaptureImage image: UIImage) {
      parent.image = image
      parent.onDismiss()
    }
  }
}

private func getSafeAreaTop() -> CGFloat {
  let scenes = UIApplication.shared.connectedScenes
  let windowScene = scenes.first { $0 is UIWindowScene } as? UIWindowScene
  let window = windowScene?.windows.first
  return window?.safeAreaInsets.top ?? 0
}

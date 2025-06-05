import SwiftUI

// CameraViewはカメラで撮影した画像を親Viewに渡すためのViewです
public struct CameraView: UIViewControllerRepresentable {
  // 撮影した画像を親Viewと共有するためのバインディング
  @Binding private var image: UIImage?

  // 画面を閉じるための環境変数
  @Environment(\.dismiss) private var dismiss

  // イニシャライザでバインディングを受け取る
  public init(image: Binding<UIImage?>) {
    self._image = image
  }

  // Coordinatorの生成
  public func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  // UIKitのUIImagePickerControllerを生成
  public func makeUIViewController(context: Context) -> UIImagePickerController {
    let viewController = UIImagePickerController()
    viewController.delegate = context.coordinator
    if UIImagePickerController.isSourceTypeAvailable(.camera) {
      viewController.sourceType = .camera
    }
    return viewController
  }

  public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context)
  {}
}

// Coordinatorクラスでデリゲート処理
extension CameraView {
  public class Coordinator: NSObject, UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
  {
    let parent: CameraView

    init(_ parent: CameraView) {
      self.parent = parent
    }

    // 撮影完了時の処理
    public func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let uiImage = info[.originalImage] as? UIImage {
        self.parent.image = uiImage  // 親Viewに画像を渡す
      }
      self.parent.dismiss()  // 画面を閉じる
    }

    // キャンセル時の処理
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      self.parent.dismiss()  // 画面を閉じる
    }
  }
}

import AVFoundation
import SwiftUI

// カメラ画面のメインView
public struct CameraView: View {
  // 撮影画像を親Viewとバインディング
  @Binding var image: UIImage?
  // 画面を閉じるための環境変数
  @Environment(\.dismiss) private var dismiss

  // 撮影ボタンの表示/非表示フラグ（手動＝表示、 自動＝非表示）
  @State private var isManualMode = true
  // カメラ制御用のモデル
  @StateObject private var cameraModel = CameraModel()

  // イニシャライザ（親Viewから画像バインディングを受け取る）
  public init(image: Binding<UIImage?>) {
    self._image = image
  }

  public var body: some View {
    ZStack {
      // カメラ映像のプレビュー
      CameraPreview(session: cameraModel.session)
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // ヘッダー（ダイナミックアイランドやノッチを避ける）
        HStack {
          // 戻るボタン
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 24))
              .padding(.leading, 16)
              .padding(.vertical, 8)
          }
          Spacer()
          // 「自動/手動」切り替えボタン
          Button(action: {
            isManualMode.toggle()
          }) {
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
        .padding(.top, 0)
        .ignoresSafeArea(edges: .horizontal)
        .padding(.top, getSafeAreaTop())

        Spacer()
        // 撮影ボタン（手動モード時のみ表示）
        if isManualMode {
          Button(action: {
            cameraModel.capturePhoto()
          }) {
            ZStack {
              // 白いリング
              Circle()
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 74, height: 74)
              // 透明な外円
              Circle()
                .fill(Color.black)
                .frame(width: 70, height: 70)
              // 白い内円
              Circle()
                .fill(Color.white)
                .frame(width: 66, height: 66)
                .shadow(radius: 2)
            }
          }
          .padding(.bottom, 50)
        }
      }
    }
    .onAppear {
      // 画面表示時にカメラセッション開始
      cameraModel.startSession()
      // 撮影完了時のコールバック
      cameraModel.onPhotoCapture = { uiImage in
        self.image = uiImage
        dismiss()
      }
    }
    .onDisappear {
      // 画面が閉じられたらカメラセッション停止
      cameraModel.stopSession()
    }
  }
}

// カメラ映像を表示するUIViewラッパー
struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = UIScreen.main.bounds
    view.layer.addSublayer(previewLayer)
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}
}

// 画面上部のセーフエリア（ノッチ・ダイナミックアイランド等）分の高さを取得する関数
private func getSafeAreaTop() -> CGFloat {
  // 現在アクティブなシーンからセーフエリアを取得
  let scenes = UIApplication.shared.connectedScenes
  let windowScene = scenes.first { $0 is UIWindowScene } as? UIWindowScene
  let window = windowScene?.windows.first
  return window?.safeAreaInsets.top ?? 0
}

// カメラ制御用クラス
class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
  let session = AVCaptureSession()  // カメラセッション
  private let output = AVCapturePhotoOutput()  // 写真出力
  var onPhotoCapture: ((UIImage) -> Void)?  // 撮影完了時のコールバック

  override init() {
    super.init()
    configure()
  }

  // カメラの設定
  private func configure() {
    session.beginConfiguration()
    guard
      let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input),
      session.canAddOutput(output)
    else {
      session.commitConfiguration()
      return
    }
    session.addInput(input)
    session.addOutput(output)
    session.commitConfiguration()
  }

  // カメラセッション開始
  func startSession() {
    if !session.isRunning {
      DispatchQueue.global(qos: .userInitiated).async {
        self.session.startRunning()
      }
    }
  }

  // カメラセッション停止
  func stopSession() {
    if session.isRunning {
      session.stopRunning()
    }
  }

  // 写真撮影
  func capturePhoto() {
    let settings = AVCapturePhotoSettings()
    output.capturePhoto(with: settings, delegate: self)
  }

  // 撮影完了時のデータ処理
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    guard let data = photo.fileDataRepresentation(),
      let uiImage = UIImage(data: data)
    else { return }
    DispatchQueue.main.async {
      self.onPhotoCapture?(uiImage)
    }
  }
}

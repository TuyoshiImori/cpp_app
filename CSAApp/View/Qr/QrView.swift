import AVFoundation
import SwiftUI
import UIKit

/// QRコード読み取り画面
struct QrView: View {
  @StateObject private var viewModel = QrViewModel()
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      // カメラプレビュー
      QrCameraPreview(session: viewModel.captureSession)
        .ignoresSafeArea()

      // スキャン枠のオーバーレイ
      VStack {
        Spacer()

        // スキャン枠
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.white, lineWidth: 3)
          .frame(width: 250, height: 250)
          .background(Color.clear)

        Spacer()

        // 説明テキスト
        Text("QRコードを枠内に収めてください")
          .font(.headline)
          .foregroundColor(.white)
          .padding()
          .background(Color.black.opacity(0.6))
          .cornerRadius(8)
          .padding(.bottom, 50)
      }

      // エラーメッセージ表示
      if let errorMessage = viewModel.errorMessage {
        VStack {
          Spacer()
          Text(errorMessage)
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.red.opacity(0.8))
            .cornerRadius(8)
          Spacer()
        }
      }

      // 閉じるボタン
      VStack {
        HStack {
          Button(action: {
            viewModel.stopScanning()
            dismiss()
          }) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 32))
              .foregroundColor(.white)
              .shadow(radius: 3)
          }
          .padding()

          Spacer()
        }
        Spacer()
      }
    }
    .navigationBarHidden(true)
    .onAppear {
      viewModel.setupCaptureSession()
      viewModel.startScanning()
    }
    .onDisappear {
      viewModel.stopScanning()
    }
    // QR読み取り結果のダイアログ
    .alert("QRコードを読み取りました", isPresented: $viewModel.showResultDialog) {
      Button("再スキャン") {
        viewModel.dismissDialogAndResume()
      }
      Button("閉じる") {
        viewModel.dismissDialog()
        dismiss()
      }
    } message: {
      Text(viewModel.scannedCode ?? "")
    }
  }
}

// MARK: - カメラプレビュー用の UIViewRepresentable

struct QrCameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)

    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = view.bounds
    view.layer.addSublayer(previewLayer)

    // レイヤーを context に保存して後で更新できるようにする
    context.coordinator.previewLayer = previewLayer

    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async {
      context.coordinator.previewLayer?.frame = uiView.bounds
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator {
    var previewLayer: AVCaptureVideoPreviewLayer?
  }
}

#Preview {
  QrView()
}

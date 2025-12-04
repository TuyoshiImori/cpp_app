import AVFoundation
import SwiftUI
import UIKit

/// QRコード読み取り画面
struct QrView: View {
  @StateObject private var viewModel = QrViewModel()
  @Environment(\.dismiss) private var dismiss
  @State private var isShowingManualIdInput: Bool = false
  @State private var manualInputId: String = ""

  // ContentViewModelからアンケート情報を渡すためのバインディング
  var onSurveyFetched: ((FirestoreSurveyDocument) -> Void)?

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
        Text("QRコードを枠内に合わせてください")
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
            .padding(.horizontal, 20)
          Spacer()
        }
      }

      // Firestore取得中のローディング表示
      if viewModel.isFetchingSurvey {
        VStack {
          Spacer()
          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.5)
              .tint(.white)
            Text("アンケート情報を取得中...")
              .font(.headline)
              .foregroundColor(.white)
          }
          .padding(30)
          .background(Color.black.opacity(0.8))
          .cornerRadius(16)
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

          // 右上: 手入力でIDを指定するボタン
          Button(action: {
            // 停止はせず、手入力シートを表示
            isShowingManualIdInput = true
          }) {
            Image(systemName: "pencil.circle.fill")
              .font(.system(size: 32))
              .foregroundColor(.white)
              .shadow(radius: 3)
          }
          .padding()
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
      Button("取得する") {
        if let code = viewModel.scannedCode {
          // Firestoreからアンケート情報を取得
          viewModel.fetchSurveyFromFirestore(documentId: code)
        }
      }
      Button("再スキャン") {
        viewModel.dismissDialogAndResume()
      }
      Button("閉じる") {
        viewModel.dismissDialog()
        dismiss()
      }
    } message: {
      if viewModel.isFetchingSurvey {
        Text("アンケート情報を取得中...")
      } else {
        Text(viewModel.scannedCode ?? "")
      }
    }
    // Firestore取得成功時の処理
    .onChange(of: viewModel.fetchedSurvey) { newValue in
      if let survey = newValue {
        // ContentViewに取得したアンケート情報を渡す
        onSurveyFetched?(survey)
        // 画面を閉じる
        viewModel.dismissDialog()
        dismiss()
      }
    }
    // 手入力ダイアログを共通コンポーネントで表示
    .overlay {
      InputDialog(
        isPresented: $isShowingManualIdInput,
        inputText: $manualInputId,
        onSubmit: { id in
          // Firestore取得を開始する
          let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty else { return }
          viewModel.fetchSurveyFromFirestore(documentId: trimmed)
        },
        dialogTitle: "アンケートIDを入力",
        placeholder: "アンケートID",
        cancelButtonText: "キャンセル",
        submitButtonText: "取得",
        isSecureInput: true,  // IDを隠す（パスワード入力のような●表示）
        showPasteButton: true  // ペーストボタンを表示
      )
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

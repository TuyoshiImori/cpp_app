import AVFoundation
import Combine
import Foundation

#if canImport(UIKit)
  import UIKit
#endif

/// QRコード読み取り画面の状態管理を担当するViewModel
final class QrViewModel: NSObject, ObservableObject {
  // MARK: - Published Properties

  /// スキャン中かどうか
  @Published var isScanning: Bool = true

  /// 読み取ったQRコードの内容
  @Published var scannedCode: String? = nil

  /// ダイアログを表示するかどうか
  @Published var showResultDialog: Bool = false

  /// エラーメッセージ（カメラ権限がない場合など）
  @Published var errorMessage: String? = nil

  /// 取得したアンケート情報
  @Published var fetchedSurvey: FirestoreSurveyDocument? = nil

  /// Firestore取得中かどうか
  @Published var isFetchingSurvey: Bool = false

  // MARK: - AVFoundation Properties

  /// カメラセッション
  let captureSession = AVCaptureSession()

  /// メタデータ出力（QRコード検出用）
  private let metadataOutput = AVCaptureMetadataOutput()

  /// セッション用のキュー
  private let sessionQueue = DispatchQueue(label: "qr.session.queue")

  // MARK: - Services

  /// Firestoreサービス
  private let firestoreService = FirestoreService.shared

  // MARK: - Lifecycle

  override init() {
    super.init()
  }

  // MARK: - Public Methods

  /// カメラセッションを設定する
  func setupCaptureSession() {
    sessionQueue.async { [weak self] in
      self?.configureCaptureSession()
    }
  }

  /// カメラセッションを開始する
  func startScanning() {
    sessionQueue.async { [weak self] in
      guard let self = self else { return }
      if !self.captureSession.isRunning {
        self.captureSession.startRunning()
      }
      DispatchQueue.main.async {
        self.isScanning = true
        self.scannedCode = nil
      }
    }
  }

  /// カメラセッションを停止する
  func stopScanning() {
    sessionQueue.async { [weak self] in
      guard let self = self else { return }
      if self.captureSession.isRunning {
        self.captureSession.stopRunning()
      }
      DispatchQueue.main.async {
        self.isScanning = false
      }
    }
  }

  /// ダイアログを閉じてスキャンを再開する
  func dismissDialogAndResume() {
    showResultDialog = false
    scannedCode = nil
    startScanning()
  }

  /// ダイアログを閉じる（スキャンは再開しない）
  func dismissDialog() {
    showResultDialog = false
  }

  /// QRコードから読み取ったFirestoreのドキュメントIDでアンケート情報を取得する
  /// - Parameter documentId: FirestoreのドキュメントID
  func fetchSurveyFromFirestore(documentId: String) {
    // 既に取得中の場合は何もしない
    guard !isFetchingSurvey else { return }

    isFetchingSurvey = true
    errorMessage = nil

    Task {
      do {
        let survey = try await firestoreService.fetchSurvey(documentId: documentId)
        await MainActor.run {
          self.fetchedSurvey = survey
          self.isFetchingSurvey = false
        }
      } catch let error as FirestoreServiceError {
        await MainActor.run {
          self.errorMessage = error.localizedDescription
          self.isFetchingSurvey = false
          self.fetchedSurvey = nil
        }
      } catch {
        await MainActor.run {
          self.errorMessage = "アンケートの取得に失敗しました"
          self.isFetchingSurvey = false
          self.fetchedSurvey = nil
        }
      }
    }
  }

  // MARK: - Private Methods

  private func configureCaptureSession() {
    // カメラ権限をチェック
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      break
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        if granted {
          self?.sessionQueue.async {
            self?.configureCaptureSession()
          }
        } else {
          DispatchQueue.main.async {
            self?.errorMessage = "カメラへのアクセスが許可されていません"
          }
        }
      }
      return
    default:
      DispatchQueue.main.async { [weak self] in
        self?.errorMessage = "カメラへのアクセスが許可されていません"
      }
      return
    }

    captureSession.beginConfiguration()

    // 入力デバイスを設定
    guard let videoDevice = AVCaptureDevice.default(for: .video),
      let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
    else {
      DispatchQueue.main.async { [weak self] in
        self?.errorMessage = "カメラを初期化できませんでした"
      }
      captureSession.commitConfiguration()
      return
    }

    if captureSession.canAddInput(videoInput) {
      captureSession.addInput(videoInput)
    }

    // メタデータ出力を設定
    if captureSession.canAddOutput(metadataOutput) {
      captureSession.addOutput(metadataOutput)
      metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
      metadataOutput.metadataObjectTypes = [.qr]
    }

    captureSession.commitConfiguration()
  }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QrViewModel: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    // QRコードを検出した場合
    guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
      metadataObject.type == .qr,
      let stringValue = metadataObject.stringValue
    else {
      return
    }

    // 既にダイアログ表示中なら無視
    guard !showResultDialog else { return }

    // スキャンを停止してダイアログを表示
    stopScanning()
    scannedCode = stringValue
    showResultDialog = true

    // 振動でフィードバック
    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
  }
}

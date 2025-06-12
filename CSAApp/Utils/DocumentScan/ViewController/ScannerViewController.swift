import AVFoundation
import UIKit

final class ScannerViewController: UIViewController {
  var previewColor: UIColor = .green
  var braceColor: UIColor = .red

  private let captureSession = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private let photoOutput = AVCapturePhotoOutput()
  private var isTorchOn = false
  private var isTargetBracesVisible = true

  override func viewDidLoad() {
    super.viewDidLoad()
    setupCamera()
    setupPreviewLayer()
    view.backgroundColor = .black

    // UI追加
    let targetBraceButton = makeTargetBraceButton()
    let torchButton = makeTorchButton()
    let shutterButton = takePhotoButtonView()

    [targetBraceButton, torchButton, shutterButton].forEach {
      view.addSubview($0)
    }

    NSLayoutConstraint.activate([
      targetBraceButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      targetBraceButton.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -32),

      torchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
      torchButton.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -32),

      shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      shutterButton.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
    ])
  }

  private func setupCamera() {
    captureSession.beginConfiguration()
    defer { captureSession.commitConfiguration() }

    guard let device = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: device),
      captureSession.canAddInput(input)
    else { return }
    captureSession.addInput(input)

    if captureSession.canAddOutput(photoOutput) {
      captureSession.addOutput(photoOutput)
    }
    captureSession.startRunning()
  }

  private func setupPreviewLayer() {
    let layer = AVCaptureVideoPreviewLayer(session: captureSession)
    layer.frame = view.bounds
    layer.videoGravity = .resizeAspectFill
    view.layer.insertSublayer(layer, at: 0)
    previewLayer = layer
  }

  // MARK: - @objc アクション

  @objc func toggleTargetBraces() {
    isTargetBracesVisible.toggle()
    print("Target braces toggled: \(isTargetBracesVisible)")
  }

  @objc func showTorchUI() {
    print("Show torch UI")
  }

  @objc func toggleTorch() {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      device.torchMode = device.torchMode == .on ? .off : .on
      device.unlockForConfiguration()
      isTorchOn = device.torchMode == .on
      print("Torch toggled: \(isTorchOn)")
    } catch {
      print("Torch could not be used")
    }
  }

  @objc func captureScreen() {
    let settings = AVCapturePhotoSettings()
    photoOutput.capturePhoto(with: settings, delegate: self)
    print("Capture screen")
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.bounds
  }
}

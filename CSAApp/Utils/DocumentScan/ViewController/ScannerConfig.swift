public struct ScannerConfig {
  public var showTargetBraces: Bool = true
  public var showTorch: Bool = true
  public var manualCapture: Bool = true
  public var showProgressBar: Bool = true

  public static let all = ScannerConfig()
  public static let minimal = ScannerConfig(
    showTargetBraces: false,
    showTorch: false,
    manualCapture: false,
    showProgressBar: false
  )
}

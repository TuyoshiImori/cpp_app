import SwiftUI

/// 円グラフのスライス色を生成するユーティリティ
public enum SliceColor {
  public static func sliceColor(index: Int, total: Int) -> Color {
    let n = max(1, total)
    guard index >= 0 else { return Color.white }

    let baseHue: Double = 0.48  // 緑〜シアン寄りの色相 (0..1)

    // 明度の範囲（濃い -> 薄い） — 全体的に明るめに調整
    let darkBrightness: Double = 0.55
    let lightBrightness: Double = 0.98

    // saturation は視認性のために少し強めに固定
    let saturation: Double = 0.78

    // safeIndex は 0..(n-1) の範囲にクランプ (循環は行わない)
    let clampedIndex = min(max(0, index), n - 1)
    let denom = max(1, n - 1)
    let t = Double(clampedIndex) / Double(denom)  // 0.0 .. 1.0

    // brightness は index の増加で明るくなる（濃い->薄い）
    let brightness = darkBrightness + t * (lightBrightness - darkBrightness)

    return Color(hue: baseHue, saturation: saturation, brightness: brightness, opacity: 1.0)
  }
}

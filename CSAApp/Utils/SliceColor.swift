import SwiftUI

/// 円グラフのスライス色を生成するユーティリティ
public enum SliceColor {
  /// index, total を受け取り Color を返す
  ///
  /// 実装メモ:
  /// - 最初の5スライスは要求された固定の16進カラーパレットを返す
  /// - それ以降は白を返す（現在の仕様）
  public static func sliceColor(index: Int, total: Int) -> Color {
    // 要求された色（正確な16進指定）
    let hexColors = ["#004f46", "#047c72", "#4baca0", "#7fded1", "#b2ffff"]

    if index >= 0 && index < hexColors.count {
      return colorFromHex(hexColors[index])
    }

    return Color.white
  }

  /// hex (#RGB, #RRGGBB, #AARRGGBB など) を Color に変換するユーティリティ
  /// - 不正な入力時は白を返す（安全なフォールバック）
  /// - sRGB カラースペースを明示して期待した色を正確に表示
  private static func colorFromHex(_ hex: String) -> Color {
    var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if hexStr.hasPrefix("#") { hexStr.removeFirst() }

    // サポートする長さ:
    // 3  -> RGB (各1桁) -> expand to RRGGBB
    // 6  -> RRGGBB
    // 8  -> AARRGGBB
    switch hexStr.count {
    case 3:
      // "FA3" -> "FFAA33"
      let r = String(repeating: String(hexStr[hexStr.startIndex]), count: 2)
      let g = String(
        repeating: String(hexStr[hexStr.index(hexStr.startIndex, offsetBy: 1)]), count: 2)
      let b = String(
        repeating: String(hexStr[hexStr.index(hexStr.startIndex, offsetBy: 2)]), count: 2)
      hexStr = r + g + b
    case 6:
      // OK as-is
      break
    case 8:
      // AARRGGBB -> leave as-is
      break
    default:
      return Color.white
    }

    // より正確な数値変換：CGFloat を使って精度を保つ
    func component(from str: Substring) -> CGFloat {
      let value = Int(String(str), radix: 16) ?? 0
      return CGFloat(value) / 255.0
    }

    if hexStr.count == 6 {
      let r = component(from: hexStr.prefix(2))
      let g = component(from: hexStr.dropFirst(2).prefix(2))
      let b = component(from: hexStr.dropFirst(4).prefix(2))

      // sRGB カラースペースを明示的に指定して Color を生成
      // これにより期待した 16 進カラーと表示される色が正確に一致する
      return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: 1.0)
    }

    // 8 桁は AARRGGBB と見なす
    if hexStr.count == 8 {
      let a = component(from: hexStr.prefix(2))
      let r = component(from: hexStr.dropFirst(2).prefix(2))
      let g = component(from: hexStr.dropFirst(4).prefix(2))
      let b = component(from: hexStr.dropFirst(6).prefix(2))

      // 同様に sRGB を明示して正確な色を返す
      return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }

    // フォールバック
    return Color.white
  }
}

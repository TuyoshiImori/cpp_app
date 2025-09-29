import SwiftUI

/// 共通のボタン前景色ユーティリティ
enum ButtonForeground {
  /// ボタンの前景色を返す。ダークモード時は白、ライト時はシステムラベル色を返す
  static func color(for colorScheme: ColorScheme) -> Color {
    if colorScheme == .dark {
      return Color.white
    } else {
      #if canImport(UIKit)
        return Color(UIColor.label)
      #else
        return Color.primary
      #endif
    }
  }
}

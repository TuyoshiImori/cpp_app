import SwiftUI

/// 共通のカード背景色ユーティリティ
enum CardBackground {
  /// カード背景色を返す。ダークモード時は薄い黒、ライト時はシステム背景を返す
  static func color(for colorScheme: ColorScheme) -> Color {
    if colorScheme == .dark {
      return Color(white: 0.08)
    } else {
      #if canImport(UIKit)
        return Color(UIColor.systemBackground)
      #else
        return Color.white
      #endif
    }
  }
}

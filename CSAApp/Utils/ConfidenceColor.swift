import SwiftUI

/// 共通の信頼度→色マッピングを提供するユーティリティ
enum ConfidenceColor {
  /// Double を受け取るオーバーロード
  static func color(for confidence: Double) -> Color {
    switch confidence {
    case 80...:
      return .green
    case 60..<80:
      return .yellow
    case 40..<60:
      return .orange
    default:
      return .red
    }
  }

  /// Float を受け取るオーバーロード
  static func color(for confidence: Float) -> Color {
    return color(for: Double(confidence))
  }
}

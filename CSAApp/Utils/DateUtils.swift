import Foundation
import SwiftUI

/// 共通の日付整形ユーティリティ
/// ここにフォーマットロジックを集約し、複数箇所から使えるようにする。
public enum DateUtils {
  private static let sharedFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP_POSIX")
    f.dateFormat = "yyyy/MM/dd HH:mm:ss"
    return f
  }()

  /// 表示用のフォーマット済み文字列を返す
  public static func formattedDate(_ date: Date) -> String {
    sharedFormatter.string(from: date)
  }
}

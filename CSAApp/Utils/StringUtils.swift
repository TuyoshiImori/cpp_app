import Foundation

/// 文字列分割ユーティリティ
/// トップレベルの区切り文字のみで分割する（括弧やクォート内部の区切りは無視する）
public enum StringUtils {
  /// トップレベルで分割します。
  /// - Parameters:
  ///   - s: 入力文字列
  ///   - separators: 区切り文字集合
  ///   - omitEmptySubsequences: true の場合は空文字列を結果に含めません（既存の挙動）。false の場合は連続した区切りで生じる空要素も返します。
  public static func splitTopLevel(
    _ s: String, separators: Set<Character>, omitEmptySubsequences: Bool = true
  ) -> [String] {
    var results: [String] = []
    var current = ""
    var depth = 0
    var inQuote: Character? = nil

    for ch in s {
      if let q = inQuote {
        current.append(ch)
        if ch == q { inQuote = nil }
        continue
      }

      if ch == "\"" || ch == "'" {
        inQuote = ch
        current.append(ch)
        continue
      }

      if ch == "(" || ch == "[" || ch == "{" {
        depth += 1
        current.append(ch)
        continue
      }

      if ch == ")" || ch == "]" || ch == "}" {
        if depth > 0 { depth -= 1 }
        current.append(ch)
        continue
      }

      if depth == 0 && separators.contains(ch) {
        let token = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if omitEmptySubsequences {
          if !token.isEmpty { results.append(token) }
        } else {
          // 空トークンも許容する
          results.append(token)
        }
        current = ""
      } else {
        current.append(ch)
      }
    }

    let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if omitEmptySubsequences {
      if !last.isEmpty { results.append(last) }
    } else {
      results.append(last)
    }
    return results
  }

  public static func splitTopLevelCommas(_ s: String) -> [String] {
    return splitTopLevel(s, separators: [","])
  }
}

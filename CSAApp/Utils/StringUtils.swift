import Foundation

/// 文字列分割ユーティリティ
/// トップレベルの区切り文字のみで分割する（括弧やクォート内部の区切りは無視する）
public enum StringUtils {
  public static func splitTopLevel(_ s: String, separators: Set<Character>) -> [String] {
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
        if !token.isEmpty { results.append(token) }
        current = ""
      } else {
        current.append(ch)
      }
    }

    let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if !last.isEmpty { results.append(last) }
    return results
  }

  public static func splitTopLevelCommas(_ s: String) -> [String] {
    return splitTopLevel(s, separators: [","])
  }
}

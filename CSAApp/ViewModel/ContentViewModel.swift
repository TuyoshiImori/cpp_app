import Combine
import Foundation

final class ContentViewModel: ObservableObject {
  // QR 文字列を解析して (key, options) の配列を返す
  // 例: "single=大変良かった,良かった&multi=ポスター,出演者から"
  public func parse(_ string: String) -> [(String, [String])] {
    let query: String
    if let idx = string.firstIndex(of: "?") {
      let after = string.index(after: idx)
      query = String(string[after...])
    } else {
      query = string
    }

    var results: [(String, [String])] = []
    let parts = query.components(separatedBy: "&")
    for part in parts {
      let pair = part.components(separatedBy: "=")
      guard pair.count >= 1 else { continue }
      let key = pair[0]
      let value = pair.dropFirst().joined(separator: "=")
      let options = value.split(separator: ",").map { String($0) }.filter { !$0.isEmpty }
      results.append((key, options))
    }
    return results
  }
}

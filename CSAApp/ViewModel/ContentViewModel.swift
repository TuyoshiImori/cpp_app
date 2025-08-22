import Combine
import Foundation

final class ContentViewModel: ObservableObject {
  // QR (または URL クエリ) の文字列を解析して (key, questionText, options, rawValue) の配列を返す
  // 例: "single=設問文|選択肢A,選択肢B&multiple=別の設問文|選択肢1,選択肢2"
  public func parse(_ string: String) -> [(String, String, [String], String)] {
    let query: String
    if let idx = string.firstIndex(of: "?") {
      let after = string.index(after: idx)
      query = String(string[after...])
    } else {
      query = string
    }

    var results: [(String, String, [String], String)] = []
    let parts = query.components(separatedBy: "&")
    for part in parts {
      let pair = part.components(separatedBy: "=")
      guard pair.count >= 1 else { continue }
      let rawKey = pair[0]
      // 値に '=' が含まれている場合に備えて、rawValue を復元する
      let rawValue = pair.dropFirst().joined(separator: "=")
      // '+' を空白に変換（application/x-www-form-urlencoded の挙動）した後、
      // percent エンコードを解除する
      let valueWithSpaces = rawValue.replacingOccurrences(of: "+", with: " ")
      let decodedValue = valueWithSpaces.removingPercentEncoding ?? valueWithSpaces

      // キーもパーセントエンコードされている可能性があるためデコードしておく
      // さらに余分な空白・改行を取り除いて小文字化しておく（例: "\ntext" 等の対策）
      var decodedKey =
        (rawKey.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? rawKey)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

      // サポート: `type=xxx|...` のようにタイプ名が value 側に来る場合、
      // value から type 名を抽出して decodedKey として扱う。
      // 例: "type=text|設問文" -> decodedKey = "text"
      if decodedKey == "type" {
        let typeName: String
        if let barIndex = decodedValue.firstIndex(of: "|") {
          typeName = String(decodedValue[..<barIndex]).trimmingCharacters(
            in: .whitespacesAndNewlines
          ).lowercased()
        } else {
          let firstToken =
            decodedValue.split(separator: ",").map {
              $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.first ?? ""
          typeName = String(firstToken).lowercased()
        }
        if !typeName.isEmpty {
          decodedKey = typeName
        }
      }

      // 設問文を抽出: '|' があれば左側を設問文、そうでなければ値全体を設問文として扱う。
      let questionText: String
      if let barIndex = decodedValue.firstIndex(of: "|") {
        let left = String(decodedValue[..<barIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        questionText = left
      } else {
        questionText = decodedValue.trimmingCharacters(in: .whitespacesAndNewlines)
      }

      // 選択肢を決定: '|' があれば右側を選択肢／項目リストとしてカンマで分割
      let options: [String]
      if let barIndex = decodedValue.firstIndex(of: "|") {
        // '|' があれば右側を選択肢としてカンマで分割
        let after = decodedValue.index(after: barIndex)
        let optionsPart = String(decodedValue[after...])
        options =
          optionsPart
          .split(separator: ",")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .map { String($0) }
          .filter { !$0.isEmpty }
      } else {
        // '|' が無ければ旧フォーマット扱い: 値全体をカンマ区切りの選択肢リストとして扱う
        options =
          decodedValue
          .split(separator: ",")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .map { String($0) }
          .filter { !$0.isEmpty }
      }

      results.append((decodedKey, questionText, options, decodedValue))
    }
    return results
  }
}

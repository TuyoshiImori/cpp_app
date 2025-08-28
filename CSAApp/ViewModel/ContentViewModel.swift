import Combine
import Foundation
import SwiftData
import SwiftUI

final class ContentViewModel: ObservableObject {
  // NEW バッジやバナー表示を ViewModel 側で管理する
  @Published var newRowIDs: Set<String> = []
  @Published var showBanner: Bool = false
  @Published var bannerTitle: String = ""
  // 画面側で検出して ScrollViewReader に適用するための一時的なスクロールターゲット
  @Published var pendingScrollTo: String? = nil
  // 編集モード状態を ViewModel で管理（View はバインディングで参照）
  @Published var isEditing: Bool = false

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

  // 指定された items を表示用にソートして返す（View 側で複雑な式を避けるため）
  func sortedItems(_ items: [Item]) -> [Item] {
    items.sorted { $0.timestamp > $1.timestamp }
  }

  // rowID を決定する共通関数
  func rowID(for item: Item) -> String {
    item.surveyID.isEmpty ? String(item.timestamp.timeIntervalSince1970) : item.surveyID
  }

  // Row 表示用の軽量モデル（Identifiable にすることで ForEach を簡潔に）
  struct RowModel: Identifiable {
    let id: String
    let item: Item
  }

  func rowModels(from items: [Item]) -> [RowModel] {
    sortedItems(items).map { RowModel(id: rowID(for: $0), item: $0) }
  }

  // アイテムがタップされたときの処理（永続化や NEW フラグのクリア）
  func handleItemTapped(_ item: Item, rowID: String, modelContext: ModelContext?) {
    if item.isNew {
      item.isNew = false
      try? modelContext?.save()
    }
    // NEW バッジ集合から削除
    newRowIDs.remove(rowID)
  }

  // 通知受信時の処理: userInfo から targetRowID を抽出してバナー/NEW/スクロールをスケジュール
  func handleDidInsertSurvey(userInfo: [AnyHashable: Any]?) {
    guard let info = userInfo else { return }

    let sid = (info["surveyID"] as? String) ?? ""
    let ts = info["timestamp"] as? TimeInterval
    let targetRowID: String
    if !sid.isEmpty {
      targetRowID = sid
    } else if let ts = ts {
      targetRowID = String(ts)
    } else {
      return
    }

    DispatchQueue.main.async {
      // すぐに NEW バッジ表示用集合へ登録
      self.newRowIDs.insert(targetRowID)

      // バナー表示タイトル
      if let t = info["title"] as? String { self.bannerTitle = t }
      withAnimation(.easeOut(duration: 0.25)) { self.showBanner = true }

      // スクロールは View 側で proxy を用いて行うため、ターゲットを公開する
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        self.pendingScrollTo = targetRowID
      }

      // 数秒後に NEW バッジとバナーを消す
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        self.newRowIDs.remove(targetRowID)
        withAnimation(.easeOut(duration: 0.6)) { self.showBanner = false }
      }
    }
  }

  func clearPendingScroll() { pendingScrollTo = nil }

  // アイテム削除の責務を ViewModel に持たせる
  func delete(_ item: Item, modelContext: ModelContext?) {
    guard let ctx = modelContext else { return }
    ctx.delete(item)
    try? ctx.save()
  }

  // AccordionItem 用の軽量ヘルパーをこの ViewModel に統合
  struct AccordionItemVM {
    let item: Item
    let rowID: String

    private static let timestampFormatter: DateFormatter = {
      let f = DateFormatter()
      f.locale = Locale(identifier: "ja_JP_POSIX")
      f.dateFormat = "yyyy/M/d H:mm"
      return f
    }()

    func isExpanded(in set: Set<String>) -> Bool { set.contains(rowID) }
    func isNew(in set: Set<String>) -> Bool { set.contains(rowID) || item.isNew }
    func formattedTimestamp(_ date: Date) -> String { Self.timestampFormatter.string(from: date) }
    func toggleExpanded(_ expandedRowIDs: inout Set<String>) {
      if isExpanded(in: expandedRowIDs) {
        expandedRowIDs.remove(rowID)
      } else {
        expandedRowIDs.insert(rowID)
      }
    }
    func chevronImageName(isExpanded: Bool) -> String {
      isExpanded ? "chevron.down" : "chevron.right"
    }
    func chevronForegroundColor(isExpanded: Bool) -> Color { isExpanded ? .white : .blue }
    func chevronBackgroundColor(isExpanded: Bool) -> Color {
      isExpanded ? .blue : Color.blue.opacity(0.08)
    }
  }
}

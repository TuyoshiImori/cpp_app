import Combine
import Foundation
import SwiftData
import SwiftUI

// UIKit is required for UIImage; import only when available (avoids macOS build issues)
#if canImport(UIKit)
  import UIKit
#endif

final class ContentViewModel: ObservableObject {
  // アクションボタン（編集/削除）1つ分の幅（UI ロジックの一部だが View 側から参照されるため ViewModel に移動）
  let actionButtonWidth: CGFloat = 60
  var totalActionButtonsWidth: CGFloat { actionButtonWidth * 2 }

  // スワイプで reveal するかの閾値を取得
  func swipeRevealThreshold() -> CGFloat { totalActionButtonsWidth / 2 }

  // NEW バッジやバナー表示を ViewModel 側で管理する
  @Published var newRowIDs: Set<String> = []
  @Published var showBanner: Bool = false
  @Published var bannerTitle: String = ""
  // 画面側で検出して ScrollViewReader に適用するための一時的なスクロールターゲット
  @Published var pendingScrollTo: String? = nil
  // 編集モード状態を ViewModel で管理（View はバインディングで参照）
  @Published var isEditing: Bool = false
  // データ変更があったことを View に伝えるためのバージョントリガー
  @Published var dataVersion: UUID = UUID()

  // スライド削除機能の状態管理
  @Published var slideOffsets: [String: CGFloat] = [:]  // 各アイテムのスライドオフセット
  @Published var swipeStates: [String: SwipeState] = [:]  // 各アイテムのスワイプ状態

  // 一時的な View 側の UI 状態を ViewModel が管理することで MVVM を強化する
  @Published var dragOffsets: [String: CGFloat] = [:]  // 各アイテムのドラッグ中オフセット
  @Published var isDraggingFlags: [String: Bool] = [:]  // 各アイテムのドラッグ中フラグ
  @Published var suppressSlideAnimationFlags: [String: Bool] = [:]  // スライドアニメーション抑制フラグ
  @Published var deleteAnimationOffsets: [String: CGFloat] = [:]  // 削除時の一時オフセット

  // MARK: - Previously view-owned state moved here
  // 折りたたみ展開など View が管理していた状態を ViewModel に移す
  @Published var expandedRowIDs: Set<String> = []
  // NavigationPath を ViewModel で保持して NavigationStack と連携する
  @Published var navigationPath: NavigationPath = NavigationPath()
  // カメラやプレビューで使う画像と現在選択中の Item
  @Published var selectedImage: UIImage? = nil
  @Published var currentItem: Item? = nil

  // 編集ダイアログ関連の状態
  @Published var isShowingEditDialog: Bool = false
  @Published var editTargetItem: Item? = nil
  @Published var editTargetRowID: String = ""
  @Published var editTitleText: String = ""

  // スワイプの状態を表すenum
  enum SwipeState {
    case normal  // 通常状態
    case revealed  // 削除ボタンが表示された状態
  }

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

      // 選択肢を決定: '|' があれば右側を選択肢／項目リストとして解析
      let options: [String]
      if let barIndex = decodedValue.firstIndex(of: "|") {
        // '|' があれば右側を選択肢として解析
        let after = decodedValue.index(after: barIndex)
        let optionsPart = String(decodedValue[after...]).trimmingCharacters(
          in: .whitespacesAndNewlines)

        // JSON配列形式の判定と解析（新形式）
        if optionsPart.hasPrefix("[") && optionsPart.hasSuffix("]") {
          // JSON配列として解析を試行
          if let data = optionsPart.data(using: .utf8) {
            do {
              let jsonArray = try JSONDecoder().decode([String].self, from: data)
              options = jsonArray.filter { !$0.isEmpty }
            } catch {
              print("ContentViewModel: JSON decode error: \(error)")
              // JSON解析失敗時は空配列を返す
              options = []
            }
          } else {
            options = []
          }
        } else {
          // 従来のカンマ区切り形式（後方互換性）
          let parts = StringUtils.splitTopLevelCommas(optionsPart)
          options = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        }
      } else {
        // '|' が無ければ旧フォーマット扱い: 値全体をカンマ区切りの選択肢リストとして扱う
        let parts = StringUtils.splitTopLevelCommas(decodedValue)
        options = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
    // 保存完了後に UI 側で再描画要求を出す
    DispatchQueue.main.async {
      self.dataVersion = UUID()
    }
  }

  // スライド削除機能のメソッド群

  /// 編集モードの切り替え（すべてのアイテムのスライド状態をリセット）
  func toggleEditMode() {
    isEditing.toggle()
    if !isEditing {
      resetAllSlideStates()
    }
  }

  /// すべてのアイテムのスライド状態をリセット
  func resetAllSlideStates() {
    withAnimation(.easeInOut(duration: 0.3)) {
      slideOffsets.removeAll()
      swipeStates.removeAll()
    }
  }

  /// 編集モードに入ったときに全アイテムを右にスライドさせる
  func slideAllItemsForEdit(items: [Item]) {
    guard isEditing else { return }

    for item in items {
      let rowID = self.rowID(for: item)
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        slideOffsets[rowID] = 120  // アクションボタン2つ分（編集+削除）幅分右にスライド
        swipeStates[rowID] = .revealed
      }
    }
  }

  /// 特定のアイテムのスライド状態を設定
  func setSlideState(for rowID: String, offset: CGFloat, state: SwipeState) {
    // 編集モードでないときはユーザー操作によるスライドを無視する
    // ただしプログラム側から明示的に閉じる（normal, offset == 0）要求が来た場合は許可する
    guard isEditing || (state == .normal && offset == 0) else { return }

    slideOffsets[rowID] = offset
    swipeStates[rowID] = state
  }

  // MARK: - per-row UI state helpers
  func getDragOffset(for rowID: String) -> CGFloat { dragOffsets[rowID] ?? 0 }
  func setDragOffset(for rowID: String, _ value: CGFloat) { dragOffsets[rowID] = value }
  func clearDragOffset(for rowID: String) { dragOffsets.removeValue(forKey: rowID) }

  func setIsDragging(_ isDragging: Bool, for rowID: String) { isDraggingFlags[rowID] = isDragging }
  func isDragging(for rowID: String) -> Bool { isDraggingFlags[rowID] ?? false }

  func setSuppressSlideAnimation(for rowID: String, _ value: Bool) {
    suppressSlideAnimationFlags[rowID] = value
  }
  func isSuppressSlideAnimation(for rowID: String) -> Bool {
    suppressSlideAnimationFlags[rowID] ?? false
  }

  func setDeleteAnimationOffset(for rowID: String, _ value: CGFloat) {
    deleteAnimationOffsets[rowID] = value
  }
  func getDeleteAnimationOffset(for rowID: String) -> CGFloat { deleteAnimationOffsets[rowID] ?? 0 }

  /// 特定のアイテムのスライド削除処理
  func handleSlideDelete(_ item: Item, modelContext: ModelContext?) {
    let rowID = self.rowID(for: item)

    // スライドアウトアニメーション
    withAnimation(.easeInOut(duration: 0.3)) {
      slideOffsets[rowID] = UIScreen.main.bounds.width
    }

    // アニメーション完了後にアイテムを削除
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.delete(item, modelContext: modelContext)
      self.slideOffsets.removeValue(forKey: rowID)
      self.swipeStates.removeValue(forKey: rowID)
    }
  }

  /// アニメーション無しで削除を行うメソッド（UI 側でアニメーションを制御したい場合に使う）
  func handleSlideDeleteWithoutAnimation(_ item: Item, modelContext: ModelContext?) {
    let rowID = self.rowID(for: item)

    // 直接削除を実行し、状態を即時にクリーンアップする
    DispatchQueue.main.async {
      self.delete(item, modelContext: modelContext)
      self.slideOffsets.removeValue(forKey: rowID)
      self.swipeStates.removeValue(forKey: rowID)
    }
  }

  /// 編集状態や ViewModel 管理の一時 UI 状態を初期化する。
  /// View 側の一時状態（モーダル表示や navigationPath、画像など）は View 側でクリアする。
  func clearEditingState() {
    // 編集フラグとスライド状態をリセット
    isEditing = false
    resetAllSlideStates()

    // ViewModel が管理する一時 UI 状態をクリア
    newRowIDs.removeAll()
    pendingScrollTo = nil
    // その他の一時フラグ/オフセットもクリア
    dragOffsets.removeAll()
    isDraggingFlags.removeAll()
    suppressSlideAnimationFlags.removeAll()
    deleteAnimationOffsets.removeAll()
  }

  // AccordionItem 用の軽量ヘルパーをこの ViewModel に統合
  struct AccordionItemVM {
    let item: Item
    let rowID: String

    func isExpanded(in set: Set<String>) -> Bool { set.contains(rowID) }
    func isNew(in set: Set<String>) -> Bool { set.contains(rowID) || item.isNew }
    func formattedTimestamp(_ date: Date) -> String { DateUtils.formattedDate(date) }
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

    // スライド削除機能用のヘルパーメソッド
    func getSlideOffset(from slideOffsets: [String: CGFloat]) -> CGFloat {
      slideOffsets[rowID] ?? 0
    }

    func getSwipeState(from swipeStates: [String: ContentViewModel.SwipeState])
      -> ContentViewModel.SwipeState
    {
      swipeStates[rowID] ?? .normal
    }
  }
}

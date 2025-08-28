import SwiftData
import SwiftUI

/// ContentView から切り出したアイテム一覧。元の ScrollView / LazyVStack の責務を持つ。
struct ItemsListView: View {
  @ObservedObject var viewModel: ContentViewModel
  var items: [Item]
  @Binding var expandedRowIDs: Set<String>
  @Binding var isPresentedCameraView: Bool
  let modelContext: ModelContext?
  let onTap: (Item, String) -> Void
  let onEdit: (Item, String) -> Void

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          let rows = viewModel.rowModels(from: items)
          // 要素ベースでループし、rows.first/last を使って先頭・末尾を判定する
          // これにより削除後でも各要素の isFirst/isLast が安定して計算される
          ForEach(rows, id: \.id) { row in
            AccordionItem(
              item: row.item,
              rowID: row.id,
              isFirst: (rows.first?.id ?? "") == row.id,
              isLast: (rows.last?.id ?? "") == row.id,
              expandedRowIDs: $expandedRowIDs,
              newRowIDs: $viewModel.newRowIDs,
              viewModel: viewModel,
              modelContext: modelContext
            ) {
              onTap(row.item, row.id)
            } onEdit: { item, id in
              onEdit(item, id)
            }
            .id(row.id)
          }
        }
        // dataVersion を id に使い、削除などデータ変化時に LazyVStack の再評価を強制する
        .id(viewModel.dataVersion)
        .padding(.vertical, 0)
        .padding(.horizontal, 12)
      }
      // mimic grouped list background (approximate without UIKit)
      .background(Color(white: 0.97).ignoresSafeArea())
      .onReceive(NotificationCenter.default.publisher(for: .didInsertSurvey)) { notif in
        viewModel.handleDidInsertSurvey(userInfo: notif.userInfo)
        DispatchQueue.main.async { isPresentedCameraView = false }
      }
      .task(id: viewModel.pendingScrollTo) {
        if let target = viewModel.pendingScrollTo {
          try? await Task.sleep(nanoseconds: 120_000_000)
          proxy.scrollTo(target, anchor: .center)
          viewModel.clearPendingScroll()
        }
      }
    }
  }
}

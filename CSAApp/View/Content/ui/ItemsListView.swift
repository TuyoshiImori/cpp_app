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

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          let rows = viewModel.rowModels(from: items)
          ForEach(rows.indices, id: \.self) { index in
            let row = rows[index]
            AccordionItem(
              item: row.item,
              rowID: row.id,
              isFirst: index == 0,
              isLast: index == rows.count - 1,
              expandedRowIDs: $expandedRowIDs,
              newRowIDs: $viewModel.newRowIDs,
              viewModel: viewModel,
              modelContext: modelContext
            ) {
              onTap(row.item, row.id)
            }
            .id(row.id)
          }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 12)
      }
      // mimic grouped list background (approximate without UIKit)
      .background(Color(white: 0.97).ignoresSafeArea())
      .onReceive(NotificationCenter.default.publisher(for: .didInsertSurvey)) { notif in
        viewModel.handleDidInsertSurvey(userInfo: notif.userInfo)
        DispatchQueue.main.async { isPresentedCameraView = false }
      }
      .onChange(of: viewModel.pendingScrollTo) { target in
        if let target = target {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            proxy.scrollTo(target, anchor: .center)
            viewModel.clearPendingScroll()
          }
        }
      }
    }
  }
}

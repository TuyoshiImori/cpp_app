import SwiftData
import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = ContentViewModel()
  @Environment(\.modelContext) private var modelContext
  @Environment(\.editMode) private var editMode
  @Environment(\.scenePhase) private var scenePhase
  @Query private var items: [Item]
  // View 側で local に持っていた状態は ViewModel に移動済み

  // (手動での設問設定は廃止) ダイアログ関連の状態を削除

  // View は ViewModel の公開プロパティを参照・バインドする
  // 例: viewModel.selectedImage, viewModel.isShowingEditDialog などを使用

  // タイムスタンプを安定して表示するための DateFormatter
  private static let timestampFormatter: DateFormatter = {
    let f = DateFormatter()
    // 日本表記を固定（再現性のあるフォーマット）
    f.locale = Locale(identifier: "ja_JP_POSIX")
    f.dateFormat = "yyyy/M/d H:mm"
    return f
  }()

  var body: some View {
    NavigationStack(path: Binding(
      get: { viewModel.navigationPath },
      set: { viewModel.navigationPath = $0 }
    )) {
      // アイテム一覧部分を分割したサブビューへ移譲
      ItemsListView(
        viewModel: viewModel,
        items: items,
  expandedRowIDs: Binding(get: { viewModel.expandedRowIDs }, set: { viewModel.expandedRowIDs = $0 }),
        modelContext: modelContext,
        onTap: { item, rowID in
          // タップ時の動作は引き続き ContentView が保持
          viewModel.handleItemTapped(item, rowID: rowID, modelContext: modelContext)
          // 選択されたアイテムを currentItem にセットして CameraView に遷移
          viewModel.currentItem = item
          // 直前の選択画像があればクリアしておく
          viewModel.selectedImage = nil
          // プッシュ遷移でCameraViewに移動
          viewModel.navigationPath.append("CameraView")
        },
        onEdit: { item, rowID in
          // 編集ダイアログを表示する準備
          viewModel.editTargetItem = item
          viewModel.editTargetRowID = rowID
          viewModel.editTitleText = item.title
          viewModel.isShowingEditDialog = true
        }
      )
      .navigationDestination(for: String.self) { destination in
        if destination == "CameraView" {
          CameraView(image: Binding(get: { viewModel.selectedImage }, set: { viewModel.selectedImage = $0 }), item: viewModel.currentItem)
        }
      }
      // navigationPath の変更による副作用はここでは扱わない。
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            viewModel.toggleEditMode()
            if viewModel.isEditing { viewModel.slideAllItemsForEdit(items: items) }
          }) { Text(viewModel.isEditing ? "Done" : "Edit") }
        }
      }
    }
    // バナー表示を分離したコンポーネントで表示
    .overlay(BannerView(show: viewModel.showBanner, title: viewModel.bannerTitle))
    // 編集タイトル用の中央ダイアログ（別ファイルに切り出し）
    .overlay {
      EditTitleDialog(isPresented: Binding(get: { viewModel.isShowingEditDialog }, set: { viewModel.isShowingEditDialog = $0 }), titleText: Binding(get: { viewModel.editTitleText }, set: { viewModel.editTitleText = $0 })) { newTitle in
        if let target = viewModel.editTargetItem {
          target.title = newTitle
          try? modelContext.save()
          viewModel.dataVersion = UUID()
        }
      }
    }
    // アプリがフォアグラウンドから離れたときに編集状態を初期化
    .onChange(of: scenePhase) { (newPhase: ScenePhase) in
      if newPhase == .background || newPhase == .inactive {
        // ViewModel 側で ViewModel 管理の状態を初期化
        viewModel.clearEditingState()

        // View 側に残す view-local 状態はなし。ViewModel のプロパティをクリアしているため
        // ここでは EditMode の解放だけを行う
        editMode?.wrappedValue = .inactive
      }
    }
  }
}

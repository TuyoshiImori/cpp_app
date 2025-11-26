import SwiftData
import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = ContentViewModel()
  @Environment(\.modelContext) private var modelContext
  @Environment(\.editMode) private var editMode
  @Environment(\.scenePhase) private var scenePhase
  @Query private var items: [Item]
  // View 側で local に持っていた状態は ViewModel に移動済み

  // QR画面表示用の状態
  @State private var isShowingQrView: Bool = false

  var body: some View {
    ZStack {
      NavigationStack(
        path: Binding(
          get: { viewModel.navigationPath },
          set: { viewModel.navigationPath = $0 }
        )
      ) {
        // アイテム一覧部分を分割したサブビューへ移譲
        ItemsListView(
          viewModel: viewModel,
          items: items,
          expandedRowIDs: Binding(
            get: { viewModel.expandedRowIDs }, set: { viewModel.expandedRowIDs = $0 }),
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
            CameraView(
              image: Binding(
                get: { viewModel.selectedImage }, set: { viewModel.selectedImage = $0 }),
              item: viewModel.currentItem)
          }
        }
        // navigationPath の変更による副作用はここでは扱わない。
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
              viewModel.toggleEditMode()
              if viewModel.isEditing { viewModel.slideAllItemsForEdit(items: items) }
            }) { Text(viewModel.isEditing ? "完了" : "編集") }
          }
        }
      }
      // バナー表示を分離したコンポーネントで表示
      .overlay(BannerView(show: viewModel.showBanner, title: viewModel.bannerTitle))
      // 編集タイトル用の中央ダイアログ（別ファイルに切り出し）
      .overlay {
        EditTitleDialog(
          isPresented: Binding(
            get: { viewModel.isShowingEditDialog }, set: { viewModel.isShowingEditDialog = $0 }),
          titleText: Binding(
            get: { viewModel.editTitleText }, set: { viewModel.editTitleText = $0 })
        ) { newTitle in
          if let target = viewModel.editTargetItem {
            target.title = newTitle
            try? modelContext.save()
            viewModel.dataVersion = UUID()
          }
        }
      }

      // フローティングボタン（右下に配置）
      VStack {
        Spacer()
        HStack {
          Spacer()
          Button(action: {
            isShowingQrView = true
          }) {
            Image(systemName: "qrcode.viewfinder")
              .font(.system(size: 24, weight: .semibold))
              .foregroundColor(.white)
              .frame(width: 56, height: 56)
              .background(Color.blue)
              .clipShape(Circle())
              .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
          }
          .padding(.trailing, 20)
          .padding(.bottom, 20)
        }
      }
    }
    // QR画面をフルスクリーンで表示
    .fullScreenCover(isPresented: $isShowingQrView) {
      QrView()
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

import SwiftData
import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = ContentViewModel()
  @Environment(\.modelContext) private var modelContext
  @Environment(\.editMode) private var editMode
  @Query private var items: [Item]
  // 新規追加を示すための一時的な rowID 集合（NEW バッジ表示用）
  @State private var newRowIDs: Set<String> = []
  // 各行の設問表示を折りたたむ/展開するための状態
  @State private var expandedRowIDs: Set<String> = []
  // Banner の表示は ViewModel 側で管理する（URL 追加など外部イベントに反応するため）
  @State private var isPresentedCameraView = false
  @State private var image: UIImage?
  @State private var currentItem: Item?

  // (手動での設問設定は廃止) ダイアログ関連の状態を削除

  // 選択されたアイテムの画像を保持する状態
  @State private var selectedImage: UIImage?
  // 編集ダイアログ用の状態
  @State private var isShowingEditDialog: Bool = false
  @State private var editTargetItem: Item? = nil
  @State private var editTargetRowID: String = ""
  @State private var editTitleText: String = ""

  // タイムスタンプを安定して表示するための DateFormatter
  private static let timestampFormatter: DateFormatter = {
    let f = DateFormatter()
    // 日本表記を固定（再現性のあるフォーマット）
    f.locale = Locale(identifier: "ja_JP_POSIX")
    f.dateFormat = "yyyy/M/d H:mm"
    return f
  }()

  var body: some View {
    ZStack {
      NavigationSplitView {
        // アイテム一覧部分を分割したサブビューへ移譲
        ItemsListView(
          viewModel: viewModel,
          items: items,
          expandedRowIDs: $expandedRowIDs,
          isPresentedCameraView: $isPresentedCameraView,
          modelContext: modelContext,
          onTap: { item, rowID in
            // タップ時の動作は引き続き ContentView が保持
            viewModel.handleItemTapped(item, rowID: rowID, modelContext: modelContext)
            selectedImage = image
            isPresentedCameraView = true
          },
          onEdit: { item, rowID in
            // 編集ダイアログを表示する準備
            editTargetItem = item
            editTargetRowID = rowID
            editTitleText = item.title
            isShowingEditDialog = true
          }
        )
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
              viewModel.toggleEditMode()
              if viewModel.isEditing { viewModel.slideAllItemsForEdit(items: items) }
            }) { Text(viewModel.isEditing ? "Done" : "Edit") }
            .tint(.blue)
          }
        }
      } detail: {
        // 詳細表示を小さなコンポーネントに分離
        DetailImageView(image: image)
      }
    }
    .fullScreenCover(isPresented: $isPresentedCameraView) {
      CameraView(image: $selectedImage, item: currentItem)
        .ignoresSafeArea()
    }
    // バナー表示を分離したコンポーネントで表示
    .overlay(BannerView(show: viewModel.showBanner, title: viewModel.bannerTitle))
    // 編集タイトル用の中央ダイアログ
    .overlay {
      if isShowingEditDialog, let target = editTargetItem {
        Color.black.opacity(0.35).ignoresSafeArea()
          .onTapGesture {
            // 背景タップでキャンセル
            isShowingEditDialog = false
          }

        VStack(spacing: 16) {
          Text("タイトルを編集")
            .font(.headline)

          TextField("タイトル", text: $editTitleText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 8)

          HStack(spacing: 12) {
            Button(action: {
              // キャンセル
              isShowingEditDialog = false
            }) {
              Text("キャンセル")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: {
              // 保存: modelContext を使ってタイトルを更新
              target.title = editTitleText
              try? modelContext.save()
              // UI 側の再描画を促す
              viewModel.dataVersion = UUID()
              isShowingEditDialog = false
            }) {
              Text("保存")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .padding(20)
        .background(Color(white: 0.97))
        .cornerRadius(12)
        .frame(maxWidth: 420)
        .padding(.horizontal, 32)
        .shadow(radius: 20)
        .zIndex(1000)
      }
    }
  }
}

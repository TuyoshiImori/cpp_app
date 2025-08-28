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
  @State private var showBanner: Bool = false
  @State private var bannerTitle: String = ""
  @State private var isPresentedCameraView = false
  @State private var image: UIImage?
  @State private var currentItem: Item?

  // (手動での設問設定は廃止) ダイアログ関連の状態を削除

  // 選択されたアイテムの画像を保持する状態
  @State private var selectedImage: UIImage?

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
          modelContext: modelContext
        ) { item, rowID in
          // タップ時の動作は引き続き ContentView が保持
          viewModel.handleItemTapped(item, rowID: rowID, modelContext: modelContext)
          selectedImage = image
          isPresentedCameraView = true
        }
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
    .overlay(BannerView(show: showBanner, title: bannerTitle))
  }
}

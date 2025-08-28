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
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(viewModel.rowModels(from: items)) { row in
                let accordionItem = AccordionItem(
                  item: row.item,
                  rowID: row.id,
                  expandedRowIDs: $expandedRowIDs,
                  newRowIDs: $viewModel.newRowIDs,
                  viewModel: viewModel,
                  modelContext: modelContext
                ) {
                  viewModel.handleItemTapped(row.item, rowID: row.id, modelContext: modelContext)
                  selectedImage = image
                  isPresentedCameraView = true
                }
                accordionItem.id(row.id)
              }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
          }
          // mimic grouped list background
          .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
          .onReceive(NotificationCenter.default.publisher(for: .didInsertSurvey)) { notif in
            viewModel.handleDidInsertSurvey(userInfo: notif.userInfo)
            // ensure any full-screen cover is dismissed when survey inserted
            DispatchQueue.main.async { isPresentedCameraView = false }
          }

          // ViewModel がスクロールターゲットを公開してきたら proxy でスクロール
          .onChange(of: viewModel.pendingScrollTo) { target in
            if let target = target {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                proxy.scrollTo(target, anchor: .center)
                viewModel.clearPendingScroll()
              }
            }
          }
        }
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            // EditButton の代替。編集モード中はデフォルトの "Done" ではなく "Cancel" を表示する
            Button(action: {
              viewModel.toggleEditMode()
              if viewModel.isEditing {
                // 編集モードに入ったときに全アイテムをスライド
                viewModel.slideAllItemsForEdit(items: items)
              }
            }) {
              // 編集モードかどうかでラベルを切り替える
              Text(viewModel.isEditing ? "Done" : "Edit")
            }
            .tint(.blue)
          }
        }
      } detail: {
        if let image {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 300)
        } else {
          Text("Select an item")
        }
      }

      // Floating action button (常に画面右下に表示される + ボタン)
      EmptyView()
    }
    .fullScreenCover(isPresented: $isPresentedCameraView) {
      CameraView(image: $selectedImage, item: currentItem)  // Itemを渡す
        .ignoresSafeArea()
    }
    // バナー表示
    .overlay(
      Group {
        if showBanner {
          VStack {
            VStack(alignment: .leading, spacing: 6) {
              Text("新しいアンケートが追加されました")
                .foregroundColor(.white)
                .padding(.horizontal)
              Text("\(bannerTitle)")
                .foregroundColor(.white)
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            Spacer()
          }
          .padding()
          .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
    )
  }
}

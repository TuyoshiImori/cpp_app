import SwiftData
import SwiftUI

// ContentViewはアプリのメイン画面を定義する構造体です
struct ContentView: View {
  // modelContextはデータベース操作のための環境変数です
  @Environment(\.modelContext) private var modelContext
  // itemsはItem型の配列で、データベースから取得されます
  @Query private var items: [Item]
  // カメラ画面表示用のフラグ
  @State private var isPresentedCameraView = false
  // 撮影画像を保持する変数
  @State private var image: UIImage?

  var body: some View {
    NavigationSplitView {
      List {
        ForEach(items) { item in
          // リスト項目タップでカメラ画面を表示
          Button {
            isPresentedCameraView = true
          } label: {
            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
          }
        }
        .onDelete(perform: deleteItems)
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
        ToolbarItem {
          Button(action: addItem) {
            Label("Add Item", systemImage: "plus")
          }
        }
      }
    } detail: {
      // 撮影画像があれば表示
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .frame(width: 300)
      } else {
        Text("Select an item")
      }
    }
    // カメラ画面をフルスクリーンで表示
    .fullScreenCover(isPresented: $isPresentedCameraView) {
      CameraView(image: $image).ignoresSafeArea()
    }
  }

  // 新しいItemを追加する関数
  private func addItem() {
    withAnimation {
      let newItem = Item(timestamp: Date())
      modelContext.insert(newItem)
    }
  }

  // 指定されたインデックスのItemを削除する関数
  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(items[index])
      }
    }
  }
}

// プレビュー用
#Preview {
  ContentView()
    .modelContainer(for: Item.self, inMemory: true)
}

import SwiftData
import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = ContentViewModel()
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [Item]
  @State private var isPresentedCameraView = false
  @State private var image: UIImage?
  @State private var currentItem: Item?

  // (手動での設問設定は廃止) ダイアログ関連の状態を削除

  // 選択されたアイテムの画像を保持する状態
  @State private var selectedImage: UIImage?

  var body: some View {
    ZStack {
      NavigationSplitView {
        List {
          ForEach(items) { item in
            VStack(alignment: .leading) {
              // ID
              if !item.surveyID.isEmpty {
                Text("ID: \(item.surveyID)")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              // タイトル
              if !item.title.isEmpty {
                Text(item.title)
                  .font(.title3)
              }
              // タイムスタンプ
              Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                .font(.headline)
              // 設問
              if !item.questionTypes.isEmpty {
                ForEach(item.questionTypes, id: \.self) { questionType in
                  HStack(alignment: .top) {
                    switch questionType {
                    case .single(let question, let options):
                      Image(systemName: "checkmark.circle")
                        .foregroundColor(.blue)
                      VStack(alignment: .leading) {
                        Text("\(question)")
                        Text(options.joined(separator: ","))
                          .font(.subheadline)
                          .foregroundColor(.gray)
                          .lineLimit(1)
                          .truncationMode(.tail)
                      }
                    case .multiple(let question, let options):
                      Image(systemName: "list.bullet")
                        .foregroundColor(.green)
                      VStack(alignment: .leading) {
                        Text("\(question)")
                        Text(options.joined(separator: ","))
                          .font(.subheadline)
                          .foregroundColor(.gray)
                          .lineLimit(1)
                          .truncationMode(.tail)
                      }
                    case .text(let question):
                      Image(systemName: "textformat")
                        .foregroundColor(.orange)
                      Text("\(question)")
                    case .info(let question, let fields):
                      Image(systemName: "person.crop.circle")
                        .foregroundColor(.purple)
                      VStack(alignment: .leading) {
                        Text("\(question)")
                        Text(fields.map { $0.displayName }.joined(separator: ","))
                          .font(.subheadline)
                          .foregroundColor(.gray)
                          .lineLimit(1)
                          .truncationMode(.tail)
                      }
                    }
                    Spacer()
                  }
                }
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
              selectedImage = image
              isPresentedCameraView = true
            }
          }
          .onDelete(perform: deleteItems)
        }
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
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
    // QR スキャナ経由のインポートは現在使用しないため削除済み
    // 手動での設問設定は廃止しているため、関連シートは削除
  }

  // 手動での設問追加 UI を廃止したため、addItem() は不要となった

  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(items[index])
      }
    }
  }
}

import SwiftData
import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = ContentViewModel()
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [Item]
  @State private var isPresentedCameraView = false
  @State private var image: UIImage?
  @State private var currentItem: Item?

  // ダイアログ表示用の状態
  @State private var isPresentedQuestionDialog = false
  @State private var selectedQuestionTypes: [QuestionType] = []

  // 選択されたアイテムの画像を保持する状態
  @State private var selectedImage: UIImage?

  var body: some View {
    ZStack {
      NavigationSplitView {
        List {
          ForEach(items) { item in
            VStack(alignment: .leading) {
              Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                .font(.headline)
              if !item.questionTypes.isEmpty {
                Text("設問タイプ:")
                  .font(.subheadline)
                  .foregroundColor(.gray)
                ForEach(item.questionTypes, id: \.self) { questionType in
                  HStack(alignment: .top) {
                    switch questionType {
                    case .single(let options):
                      Image(systemName: "checkmark.circle")
                        .foregroundColor(.blue)
                      Text("単数回答: \(options.joined(separator: ","))")
                    case .multiple(let options):
                      Image(systemName: "list.bullet")
                        .foregroundColor(.green)
                      Text("複数回答: \(options.joined(separator: ","))")
                    case .freeText:
                      Image(systemName: "textformat")
                        .foregroundColor(.orange)
                      Text("自由記述")
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
            HStack {
              EditButton()
                .tint(.blue)
              Button(action: {
                // 従来の設問タイプ選択画面を開く
                selectedQuestionTypes = []
                isPresentedQuestionDialog = true
              }) {
                Image(systemName: "plus")
              }
              .tint(.blue)
            }
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
      VStack {
        Spacer()
        HStack {
          Spacer()
          Button(action: {
            selectedQuestionTypes = []
            isPresentedQuestionDialog = true
          }) {
            Image(systemName: "plus")
              .font(.system(size: 22, weight: .bold))
              .foregroundColor(.white)
              .frame(width: 56, height: 56)
          }
          .background(Color.blue)
          .clipShape(Circle())
          .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
          .padding(.trailing, 16)
          .padding(.bottom, 16)
        }
      }
    }
    .fullScreenCover(isPresented: $isPresentedCameraView) {
      CameraView(image: $selectedImage, item: currentItem)  // Itemを渡す
        .ignoresSafeArea()
    }
    // QR スキャナ経由のインポートは現在使用しないため削除済み
    .sheet(isPresented: $isPresentedQuestionDialog) {
      QuestionTypeSelectionView(
        selectedQuestionTypes: $selectedQuestionTypes,
        onComplete: { addItem() }
      )
    }
  }

  private func addItem() {
    withAnimation {
      let newItem = Item(timestamp: Date(), questionTypes: selectedQuestionTypes)
      modelContext.insert(newItem)
      isPresentedQuestionDialog = false  // QuestionTypeSelectionViewを閉じる
      isPresentedCameraView = true  // CameraViewを開く
    }
  }

  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(items[index])
      }
    }
  }
}

import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [Item]
  @State private var isPresentedCameraView = false
  @State private var image: UIImage?

  // ダイアログ表示用の状態
  @State private var isPresentedQuestionDialog = false
  @State private var selectedQuestionTypes: [QuestionType] = []

  // 選択されたアイテムの画像を保持する状態
  @State private var selectedImage: UIImage?

  var body: some View {
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
                  case .singleChoice:
                    Image(systemName: "checkmark.circle")
                      .foregroundColor(.blue)
                    Text("単数回答")
                  case .multipleChoice:
                    Image(systemName: "list.bullet")
                      .foregroundColor(.green)
                    Text("複数回答")
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
          EditButton()
        }
        ToolbarItem {
          Button(action: {
            selectedQuestionTypes = []
            isPresentedQuestionDialog = true
          }) {
            Label("Add Item", systemImage: "plus")
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
    .fullScreenCover(isPresented: $isPresentedCameraView) {
      CameraView(image: $selectedImage, item: items.first)  // Itemを渡す
        .ignoresSafeArea()
    }
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

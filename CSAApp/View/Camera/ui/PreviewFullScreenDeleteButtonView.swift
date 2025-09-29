import SwiftData
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// プレビュー画面の右下に表示される削除ボタンの独立した View
struct PreviewFullScreenDeleteButtonView: View {
  @Binding var previewIndex: Int
  let croppedImageSets: [[UIImage]]
  let parsedAnswersSets: [[String]]
  let item: Item?
  var viewModel: CameraViewModel?
  @Binding var isPreviewPresented: Bool
  var onDelete: ((Int) -> Bool)?

  // convenience init-like factory for previews/tests
  init(
    previewIndex: Binding<Int>,
    croppedImageSets: [[UIImage]] = [],
    parsedAnswersSets: [[String]] = [],
    item: Item? = nil,
    viewModel: CameraViewModel? = nil,
    isPreviewPresented: Binding<Bool>,
    onDelete: ((Int) -> Bool)? = nil
  ) {
    self._previewIndex = previewIndex
    self.croppedImageSets = croppedImageSets
    self.parsedAnswersSets = parsedAnswersSets
    self.item = item
    self.viewModel = viewModel
    self._isPreviewPresented = isPreviewPresented
    self.onDelete = onDelete
  }

  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme
  @State private var showConfirm = false

  var body: some View {
    Button(role: .destructive) {
      showConfirm = true
    } label: {
      HStack {
        Image(systemName: "trash")
        Text("削除")
          .font(.headline)
      }
      .foregroundColor(ButtonForeground.color(for: colorScheme))
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
    .glassEffect(.regular.tint(Color.red.opacity(0.7)).interactive())
    .confirmationDialog("この回答を削除しますか？", isPresented: $showConfirm, titleVisibility: .visible) {
      Button("削除", role: .destructive) {
        var shouldClose = true
        if let callback = onDelete {
          shouldClose = callback(previewIndex)
        } else if let vm = viewModel {
          shouldClose = vm.deleteDataSet(at: previewIndex, item: item, modelContext: modelContext)
        } else if let it = item {
          modelContext.delete(it)
          shouldClose = true
        }

        if shouldClose {
          isPreviewPresented = false
        }
      }
    }
  }
}

struct PreviewFullScreenDeleteButtonView_Previews: PreviewProvider {
  @State static var idx = 0
  @State static var isPresented = true
  static var previews: some View {
    PreviewFullScreenDeleteButtonView(
      previewIndex: $idx,
      isPreviewPresented: $isPresented
    )
  }
}

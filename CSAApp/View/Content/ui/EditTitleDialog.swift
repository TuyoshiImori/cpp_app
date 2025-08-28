import SwiftUI

/// 中央に表示する編集ダイアログ（タイトル編集用）。
struct EditTitleDialog: View {
  @Binding var isPresented: Bool
  @Binding var titleText: String
  var onSave: (String) -> Void

  var body: some View {
    if isPresented {
      ZStack {
        Color.black.opacity(0.35).ignoresSafeArea()
          .onTapGesture { isPresented = false }

        VStack(spacing: 16) {
          Text("タイトルを編集")
            .font(.headline)

          TextField("タイトル", text: $titleText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 8)

          HStack(spacing: 12) {
            Button(action: {
              isPresented = false
            }) {
              Text("キャンセル")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: {
              onSave(titleText)
              isPresented = false
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

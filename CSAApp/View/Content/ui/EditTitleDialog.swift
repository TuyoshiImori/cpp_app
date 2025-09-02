import SwiftUI

/// 中央に表示する編集ダイアログ（タイトル編集用）。
struct EditTitleDialog: View {
  @Binding var isPresented: Bool
  @Binding var titleText: String
  var onSave: (String) -> Void
  @FocusState private var textFieldFocused: Bool

  var body: some View {
    ZStack {
      // 背景の半透明レイヤー
      Color.black.opacity(isPresented ? 0.35 : 0.0)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.18), value: isPresented)
        .onTapGesture {
          withAnimation { isPresented = false }
        }

      // ダイアログ本体
      VStack(spacing: 16) {
        Text("タイトルを編集")
          .font(.headline)

        TextField("タイトル", text: $titleText)
          .textFieldStyle(.roundedBorder)
          .padding(.horizontal, 8)
          .focused($textFieldFocused)

        HStack(spacing: 12) {
          Button(action: {
            withAnimation { isPresented = false }
            textFieldFocused = false
          }) {
            Text("キャンセル")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)

          Button(action: {
            onSave(titleText)
            withAnimation { isPresented = false }
            textFieldFocused = false
          }) {
            Text("保存")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .padding(20)
      .background(Color(.systemBackground))
      .cornerRadius(12)
      .frame(maxWidth: 420)
      .padding(.horizontal, 32)
      .shadow(radius: 20)
      .zIndex(1000)
      // フェードイン／アウト
      .opacity(isPresented ? 1.0 : 0.0)
      .scaleEffect(isPresented ? 1.0 : 0.98)
      .animation(.easeInOut(duration: 0.18), value: isPresented)
      // 表示されていないときはヒットテストを無効化
      .allowsHitTesting(isPresented)
      .task(id: isPresented) {
        if isPresented {
          // 少し遅延してフォーカスを与えると確実にキーボードが上がる
          try? await Task.sleep(nanoseconds: 80_000_000)
          textFieldFocused = true
        } else {
          textFieldFocused = false
        }
      }
    }
  }
}

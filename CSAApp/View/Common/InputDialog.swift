import SwiftUI

#if canImport(UIKit)
  import UIKit  // UIPasteboard のために追加
#endif

/// 中央に表示する汎用入力ダイアログ。タイトル編集、ID入力など様々な用途で使用可能。
struct InputDialog: View {
  @Binding var isPresented: Bool
  @Binding var inputText: String
  var onSubmit: (String) -> Void
  @FocusState private var textFieldFocused: Bool

  // カスタマイズ可能なパラメータ
  var dialogTitle: String = "入力"
  var placeholder: String = "入力してください"
  var cancelButtonText: String = "キャンセル"
  var submitButtonText: String = "決定"
  var isSecureInput: Bool = false  // セキュアな入力（文字を隠す）
  var showPasteButton: Bool = false  // ペーストボタンを表示するか

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
        Text(dialogTitle)
          .font(.headline)

        // テキスト入力欄（セキュアモード対応 + ペーストボタン）
        HStack(spacing: 8) {
          if isSecureInput {
            // セキュアフィールド（文字を●で隠す）
            SecureField(placeholder, text: $inputText)
              .textFieldStyle(.roundedBorder)
              .focused($textFieldFocused)
          } else {
            // 通常のテキストフィールド
            TextField(placeholder, text: $inputText)
              .textFieldStyle(.roundedBorder)
              .focused($textFieldFocused)
          }

          // ペーストボタン（オプション）
          if showPasteButton {
            Button(action: {
              // クリップボードから貼り付け
              #if canImport(UIKit)
                if let clipboardString = UIPasteboard.general.string {
                  inputText = clipboardString
                }
              #endif
            }) {
              Image(systemName: "doc.on.clipboard")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
            }
          }
        }
        .padding(.horizontal, 8)

        HStack(spacing: 12) {
          Button(action: {
            withAnimation { isPresented = false }
            textFieldFocused = false
          }) {
            Text(cancelButtonText)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)

          Button(action: {
            onSubmit(inputText)
            withAnimation { isPresented = false }
            textFieldFocused = false
          }) {
            Text(submitButtonText)
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

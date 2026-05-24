import SwiftUI

struct LoginView: View {
  @EnvironmentObject private var auth: AuthService
  @State private var isLoading = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 32) {
      Spacer()
      Image(systemName: "music.note.list")
        .font(.system(size: 64))
        .foregroundColor(.blue)
      VStack(spacing: 8) {
        Text("CSA App")
          .font(.largeTitle.bold())
        Text("Googleアカウントでログインしてください")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      if let error = errorMessage {
        Text(error)
          .foregroundColor(.red)
          .font(.caption)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }
      Button(action: signIn) {
        HStack(spacing: 12) {
          if isLoading {
            ProgressView().tint(.white)
          } else {
            Image(systemName: "g.circle.fill")
          }
          Text("Google でログイン")
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isLoading ? Color.blue.opacity(0.6) : Color.blue)
        .cornerRadius(12)
      }
      .disabled(isLoading)
      .padding(.horizontal, 32)
      Spacer()
    }
    .padding()
  }

  private func signIn() {
    isLoading = true
    errorMessage = nil
    Task {
      do {
        try await auth.signInWithGoogle()
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }
}

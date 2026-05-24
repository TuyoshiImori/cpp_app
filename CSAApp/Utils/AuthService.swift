import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn

#if canImport(UIKit)
  import UIKit
#endif

@MainActor
final class AuthService: ObservableObject {
  static let shared = AuthService()

  @Published var user: User? = Auth.auth().currentUser
  private var listener: AuthStateDidChangeListenerHandle?

  private init() {
    listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      Task { @MainActor in self?.user = user }
    }
  }

  deinit {
    if let l = listener { Auth.auth().removeStateDidChangeListener(l) }
  }

  var isSignedIn: Bool { user != nil }
  var uid: String? { user?.uid }
  var displayName: String { user?.displayName ?? "ユーザー" }
  var email: String? { user?.email }
  var photoURL: URL? { user?.photoURL }

  func signInWithGoogle() async throws {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
      throw AuthError.missingClientID
    }
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    guard
      let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let rootVC = windowScene.windows.first?.rootViewController
    else {
      throw AuthError.noRootViewController
    }
    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
    guard let idToken = result.user.idToken?.tokenString else {
      throw AuthError.missingToken
    }
    let credential = GoogleAuthProvider.credential(
      withIDToken: idToken,
      accessToken: result.user.accessToken.tokenString
    )
    try await Auth.auth().signIn(with: credential)
  }

  func signOut() throws {
    GIDSignIn.sharedInstance.signOut()
    try Auth.auth().signOut()
  }

  enum AuthError: LocalizedError {
    case missingClientID, noRootViewController, missingToken

    var errorDescription: String? {
      switch self {
      case .missingClientID: return "Firebase ClientID が見つかりません"
      case .noRootViewController: return "rootViewController が取得できません"
      case .missingToken: return "認証トークンの取得に失敗しました"
      }
    }
  }
}

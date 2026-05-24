//
//  CSAAppApp.swift
//  CSAApp
//
//  Created by 飯森毅 on 2025/06/05.
//

import FirebaseCore
import GoogleSignIn
import SwiftData
import SwiftUI

extension Notification.Name {
  static let didInsertSurvey = Notification.Name("didInsertSurvey")
}

// Firebaseを初期化するクラス
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Firebaseを初期化
    FirebaseApp.configure()
    return true
  }
}

@main
struct CSAAppApp: App {
  // AppDelegateを登録
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var authService = AuthService.shared
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([Item.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      // スキーマ変更で自動マイグレーションに失敗した場合、古いストアを削除して再作成する
      // （既存データは失われるが、開発中のスキーマ変更に対応するため許容する）
      print("⚠️ SwiftData migration failed, recreating store: \(error)")
      let appSupport = URL.applicationSupportDirectory
      for name in ["default.store", "default.store-shm", "default.store-wal"] {
        try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
      }
      do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
      } catch {
        fatalError("Could not create ModelContainer: \(error)")
      }
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(authService)
        .onOpenURL { url in
          GIDSignIn.sharedInstance.handle(url)
        }
    }
    .modelContainer(sharedModelContainer)
  }
}

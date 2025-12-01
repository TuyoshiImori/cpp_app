//
//  CSAAppApp.swift
//  CSAApp
//
//  Created by 飯森毅 on 2025/06/05.
//

import FirebaseCore
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
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Item.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}

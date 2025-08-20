//
//  CSAAppApp.swift
//  CSAApp
//
//  Created by 飯森毅 on 2025/06/05.
//

import SwiftData
import SwiftUI

@main
struct CSAAppApp: App {
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
        .onOpenURL { url in
          // URL でアプリが開かれたときの処理
          let vm = ContentViewModel()
          let parsed = vm.parse(url.absoluteString)
          var qtypes: [QuestionType] = []
          for (key, options) in parsed {
            switch key {
            case "single", "type=single":
              qtypes.append(.single(options))
            case "multi", "multiple", "type=multi", "type=multiple":
              qtypes.append(.multiple(options))
            case "text", "type=text", "info", "type=info":
              qtypes.append(.freeText)
            default:
              continue
            }
          }
          if !qtypes.isEmpty {
            // sharedModelContainer の mainContext に挿入（メインスレッド）
            let context = sharedModelContainer.mainContext
            let newItem = Item(timestamp: Date(), questionTypes: qtypes)
            context.insert(newItem)
            try? context.save()
          }
        }
    }
    .modelContainer(sharedModelContainer)
  }
}

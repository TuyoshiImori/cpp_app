//
//  CSAAppApp.swift
//  CSAApp
//
//  Created by 飯森毅 on 2025/06/05.
//

import SwiftData
import SwiftUI

extension Notification.Name {
  static let didInsertSurvey = Notification.Name("didInsertSurvey")
}

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
          var surveyID: String? = nil
          var title: String? = nil

          for (key, questionText, options, rawValue) in parsed {
            // id と title がクエリとして含まれている場合は抽出
            if key == "id" {
              surveyID = questionText.isEmpty ? rawValue : questionText
              continue
            }
            if key == "title" {
              title = questionText.isEmpty ? rawValue : questionText
              continue
            }

            switch key {
            case "single", "type=single":
              qtypes.append(.single(questionText, options))
            case "multiple", "type=multiple":
              qtypes.append(.multiple(questionText, options))
            case "text", "type=text":
              qtypes.append(.text(questionText))
            case "info", "type=info":
              // options は文字列の配列なので InfoField に変換する（不明なフィールドは無視）
              let infoFields = options.compactMap { QuestionType.InfoField(from: $0) }
              qtypes.append(.info(questionText, infoFields))
            default:
              continue
            }
          }

          guard !qtypes.isEmpty else { return }

          let context = sharedModelContainer.mainContext

          // surveyID が与えられていれば既存のものを検索して重複を避ける
          if let sid = surveyID, !sid.isEmpty {
            // シンプルに全 Item を取得して surveyID が一致するものがあるかをチェック
            let fetch = FetchDescriptor<Item>()
            if let existing = try? context.fetch(fetch) {
              if existing.contains(where: { $0.surveyID == sid }) {
                return  // 同じ ID のものが既に存在するため作成しない
              }
            }
          }

          let newItem = Item(
            timestamp: Date(), questionTypes: qtypes, surveyID: surveyID ?? "", title: title ?? "",
            isNew: true)
          context.insert(newItem)
          try? context.save()
          // 新規追加の通知を出す（timestamp を送る）
          NotificationCenter.default.post(
            name: .didInsertSurvey,
            object: nil,
            userInfo: [
              "timestamp": newItem.timestamp.timeIntervalSince1970,
              "surveyID": newItem.surveyID,
              "title": newItem.title,
            ]
          )
        }
    }
    .modelContainer(sharedModelContainer)
  }
}

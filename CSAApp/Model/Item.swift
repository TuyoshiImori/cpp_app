import Foundation
import SwiftData

enum QuestionType: Codable {
  case singleChoice
  case multipleChoice
  case freeText
}

@Model
final class Item {
  var timestamp: Date
  var questionTypes: [QuestionType]  // 設問タイプを保存するプロパティ

  init(timestamp: Date, questionTypes: [QuestionType] = []) {
    self.timestamp = timestamp
    self.questionTypes = questionTypes
  }
}

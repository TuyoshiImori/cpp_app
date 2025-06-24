import Foundation
import SwiftData

public enum QuestionType: Codable {
  case singleChoice
  case multipleChoice
  case freeText
}

@Model
public final class Item {
  public var timestamp: Date
  public var questionTypes: [QuestionType]  // 設問タイプを保存するプロパティ

  public init(timestamp: Date, questionTypes: [QuestionType] = []) {
    self.timestamp = timestamp
    self.questionTypes = questionTypes
  }
}

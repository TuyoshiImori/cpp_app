import Foundation
import SwiftData

public enum QuestionType: Codable, Hashable {
  case single(String, [String])
  case multiple(String, [String])
  case text(String)

  private enum CodingKeys: String, CodingKey {
    case type
    case question
    case options
  }

  private enum StoredType: String, Codable {
    case single
    case multiple
    case text
  }

  public init(from decoder: Decoder) throws {
    // 1) 普通の（新しい）形式を試す
    if let keyedContainer = try? decoder.container(keyedBy: CodingKeys.self) {
      if let storedType = try? keyedContainer.decode(StoredType.self, forKey: .type) {
        let question = try keyedContainer.decodeIfPresent(String.self, forKey: .question) ?? ""
        switch storedType {
        case .single:
          let options = try keyedContainer.decodeIfPresent([String].self, forKey: .options) ?? []
          self = .single(question, options)
        case .multiple:
          let options = try keyedContainer.decodeIfPresent([String].self, forKey: .options) ?? []
          self = .multiple(question, options)
        case .text:
          self = .text(question)
        }
        return
      }
    }

    // 2) 旧形式（キー無し、単純な文字列など）を試す
    let singleValue = try? decoder.singleValueContainer()
    if let singleValue = singleValue, let legacy = try? singleValue.decode(String.self) {
      switch legacy.lowercased() {
      case "single":
        self = .single("", [])
        return
      case "multiple":
        self = .multiple("", [])
        return
      case "text":
        self = .text("")
        return
      default:
        break
      }
    }

    // 3) それでも復元できない場合は安全なデフォルトにする
    self = .text("")
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .single(let question, let options):
      try container.encode(StoredType.single, forKey: .type)
      try container.encode(question, forKey: .question)
      try container.encode(options, forKey: .options)
    case .multiple(let question, let options):
      try container.encode(StoredType.multiple, forKey: .type)
      try container.encode(question, forKey: .question)
      try container.encode(options, forKey: .options)
    case .text(let question):
      try container.encode(StoredType.text, forKey: .type)
      try container.encode(question, forKey: .question)
    }
  }
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

import Foundation
import SwiftData

public enum QuestionType: Codable, Hashable {
  case single(String, [String])
  case multiple(String, [String])
  case text(String)
  case info(String, [InfoField])

  // 個人情報フィールドの型（内部保存と表示用日本語ラベル）
  public enum InfoField: String, Codable, Hashable {
    case furigana
    case name
    case nameKana
    case email
    case tel
    case zip
    case address

    // 表示用の日本語ラベル
    public var displayName: String {
      switch self {
      case .furigana: return "ふりがな"
      case .name: return "氏名"
      case .nameKana: return "氏名（ふりがな）"
      case .email: return "メールアドレス"
      case .tel: return "電話番号"
      case .zip: return "郵便番号"
      case .address: return "住所"
      }
    }

    // 文字列から InfoField に変換する（大文字小文字や別表記に寛容）
    public init?(from raw: String) {
      let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      switch key {
      case "furigana": self = .furigana
      case "name": self = .name
      case "namekana", "name_kana", "name-kana": self = .nameKana
      case "email", "e-mail", "mail": self = .email
      case "tel", "telephone", "phone", "phone_number", "phone-number": self = .tel
      case "zip", "zipcode", "post", "postal": self = .zip
      case "address", "addr": self = .address
      default: return nil
      }
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case question
    case options
  }

  private enum StoredType: String, Codable {
    case single
    case multiple
    case text
    case info
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
        case .info:
          let stringOptions =
            try keyedContainer.decodeIfPresent([String].self, forKey: .options) ?? []
          // 文字列配列を InfoField に変換（不明なフィールドは無視）
          let infoFields: [InfoField] = stringOptions.compactMap { InfoField(from: $0) }
          self = .info(question, infoFields)
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
      case "info":
        self = .info("", [])
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
    case .info(let question, let options):
      try container.encode(StoredType.info, forKey: .type)
      try container.encode(question, forKey: .question)
      // InfoField を文字列にして保存
      let stringOptions = options.map { $0.rawValue }
      try container.encode(stringOptions, forKey: .options)
    }
  }
}

@Model
public final class Item {
  public var timestamp: Date
  public var questionTypes: [QuestionType]  // 設問タイプを保存するプロパティ
  public var surveyID: String
  public var title: String
  // 新規追加を表すフラグ（タップで消すために永続化）
  public var isNew: Bool
  // 各設問の選択肢テキストを格納するストアドプロパティ
  public var optionTexts: [[String]]

  public init(
    timestamp: Date, questionTypes: [QuestionType] = [], surveyID: String = "",
    title: String = "", isNew: Bool = false, optionTexts: [[String]] = []
  ) {
    self.timestamp = timestamp
    self.questionTypes = questionTypes
    self.surveyID = surveyID
    self.title = title
    self.isNew = isNew
    self.optionTexts = optionTexts
  }
}

import Foundation

// MARK: - InfoFields

/// 個人情報設問で保持する項目フラグ
/// 各フィールドが true の場合、その項目をアンケートで取得する
public struct InfoFields: Codable, Hashable {
  public var furigana: Bool?
  public var name: Bool?
  public var nameWithFurigana: Bool?
  public var email: Bool?
  public var phone: Bool?
  public var postalCode: Bool?
  public var address: Bool?

  public init(
    furigana: Bool? = nil,
    name: Bool? = nil,
    nameWithFurigana: Bool? = nil,
    email: Bool? = nil,
    phone: Bool? = nil,
    postalCode: Bool? = nil,
    address: Bool? = nil
  ) {
    self.furigana = furigana
    self.name = name
    self.nameWithFurigana = nameWithFurigana
    self.email = email
    self.phone = phone
    self.postalCode = postalCode
    self.address = address
  }

  enum CodingKeys: String, CodingKey {
    case furigana
    case name
    case nameWithFurigana
    case email
    case phone
    case postalCode
    case address
  }
}

// MARK: - FirestoreQuestionType

/// Firestoreで定義されている設問タイプ
public enum FirestoreQuestionType: String, Codable {
  case single = "single"
  case multiple = "multiple"
  case text = "text"
  case info = "info"
}

// MARK: - FirestoreQuestion

/// 設問の型
/// - 選択系はoptionsを持つ
/// - info は InfoFields を持つ
public struct FirestoreQuestion: Codable, Hashable {
  public let index: Int
  public let type: FirestoreQuestionType

  /// 設問のタイトル（質問文）
  public let title: String?

  /// 単一/複数選択の場合の選択肢
  public let options: [String]?

  /// 個人情報設問の場合の取得項目
  public let infoFields: InfoFields?

  public init(
    index: Int,
    type: FirestoreQuestionType,
    title: String? = nil,
    options: [String]? = nil,
    infoFields: InfoFields? = nil
  ) {
    self.index = index
    self.type = type
    self.title = title
    self.options = options
    self.infoFields = infoFields
  }

  enum CodingKeys: String, CodingKey {
    case index
    case type
    case title
    case options
    case infoFields
  }
}

// MARK: - FirestoreSurveyDocument

/// アンケートドキュメント
public struct FirestoreSurveyDocument: Codable, Hashable {
  public let id: String
  public let title: String
  public let questions: [FirestoreQuestion]
  public let createdAt: Date?
  public let updatedAt: Date?

  public init(
    id: String,
    title: String,
    questions: [FirestoreQuestion],
    createdAt: Date? = nil,
    updatedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.questions = questions
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case questions
    case createdAt
    case updatedAt
  }
}

import Foundation
import SwiftData

#if canImport(UIKit)
  import UIKit
#endif

@Model
public final class ScanResult {
  public var scanID: String  // 固有のスキャンID
  public var timestamp: Date  // スキャン実行時刻
  public var confidenceScores: [Float]  // 各設問の信頼度スコア
  public var confidenceScores2D: [[Float]]  // info設問など行ごとの信頼度スコア
  public var answerTexts: [String]  // 各設問の回答文
  public var questionImageData: [Data?]  // 各設問の切り取り画像データ

  public init(
    scanID: String = UUID().uuidString,
    timestamp: Date = Date(),
    confidenceScores: [Float] = [],
    confidenceScores2D: [[Float]] = [],
    answerTexts: [String] = [],
    questionImageData: [Data?] = []
  ) {
    self.scanID = scanID
    self.timestamp = timestamp
    self.confidenceScores = confidenceScores
    self.confidenceScores2D = confidenceScores2D
    self.answerTexts = answerTexts
    self.questionImageData = questionImageData
  }

  #if canImport(UIKit)
    /// 保存された画像データからUIImageを復元するメソッド
    /// - Parameter index: 復元したい設問画像のインデックス
    /// - Returns: 復元されたUIImage、またはnil
    public func getQuestionImage(at index: Int) -> UIImage? {
      guard index >= 0, index < questionImageData.count else { return nil }
      guard let data = questionImageData[index] else { return nil }
      return UIImage(data: data)
    }

    /// すべての設問画像を復元するメソッド
    /// - Returns: 復元されたUIImageの配列（復元できなかった画像はnilとして配列に含まれる）
    public func getAllQuestionImages() -> [UIImage?] {
      return questionImageData.map { data in
        guard let data = data else { return nil }
        return UIImage(data: data)
      }
    }
  #endif
}

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

  // 複数のスキャン結果を保持するための配列
  public var scanResults: [ScanResult]

  // 後方互換性のための一時的なプロパティ（将来的には削除予定）
  public var confidenceScores: [Float]
  public var answerTexts: [String]
  public var questionImageData: [Data?]

  public init(
    timestamp: Date, questionTypes: [QuestionType] = [], surveyID: String = "",
    title: String = "", isNew: Bool = false, optionTexts: [[String]] = [],
    scanResults: [ScanResult] = [],
    confidenceScores: [Float] = [], answerTexts: [String] = [], questionImageData: [Data?] = []
  ) {
    self.timestamp = timestamp
    self.questionTypes = questionTypes
    self.surveyID = surveyID
    self.title = title
    self.isNew = isNew
    self.optionTexts = optionTexts
    self.scanResults = scanResults
    self.confidenceScores = confidenceScores
    self.answerTexts = answerTexts
    self.questionImageData = questionImageData
  }

  #if canImport(UIKit)
    /// 最新のスキャン結果から画像を復元するメソッド
    /// - Parameter index: 復元したい設問画像のインデックス
    /// - Returns: 復元されたUIImage、またはnil
    public func getQuestionImage(at index: Int) -> UIImage? {
      // 最新のスキャン結果を取得
      guard let latestScanResult = getLatestScanResult() else {
        // 後方互換性: 古いデータ構造から復元を試行
        guard index >= 0, index < questionImageData.count else { return nil }
        guard let data = questionImageData[index] else { return nil }
        return UIImage(data: data)
      }
      return latestScanResult.getQuestionImage(at: index)
    }

    /// 最新のスキャン結果からすべての設問画像を復元するメソッド
    /// - Returns: 復元されたUIImageの配列（復元できなかった画像はnilとして配列に含まれる）
    public func getAllQuestionImages() -> [UIImage?] {
      // 最新のスキャン結果を取得
      guard let latestScanResult = getLatestScanResult() else {
        // 後方互換性: 古いデータ構造から復元を試行
        return questionImageData.map { data in
          guard let data = data else { return nil }
          return UIImage(data: data)
        }
      }
      return latestScanResult.getAllQuestionImages()
    }

    /// 特定のスキャン結果から画像を復元するメソッド
    /// - Parameters:
    ///   - scanID: 取得したいスキャン結果のID
    ///   - index: 復元したい設問画像のインデックス
    /// - Returns: 復元されたUIImage、またはnil
    public func getQuestionImage(scanID: String, at index: Int) -> UIImage? {
      guard let scanResult = scanResults.first(where: { $0.scanID == scanID }) else { return nil }
      return scanResult.getQuestionImage(at: index)
    }
  #endif

  /// 最新のスキャン結果を取得するメソッド
  /// - Returns: 最新のScanResult、またはnil
  public func getLatestScanResult() -> ScanResult? {
    return scanResults.max(by: { $0.timestamp < $1.timestamp })
  }

  /// 新しいスキャン結果を追加するメソッド
  /// - Parameter scanResult: 追加するScanResult
  public func addScanResult(_ scanResult: ScanResult) {
    scanResults.append(scanResult)
  }
}

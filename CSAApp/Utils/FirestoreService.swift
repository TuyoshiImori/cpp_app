import FirebaseFirestore
import Foundation

// MARK: - FirestoreServiceError

/// Firestore操作で発生する可能性のあるエラー
enum FirestoreServiceError: Error, LocalizedError {
  case networkError(String)
  case notFound
  case invalidData
  case invalidDocumentId
  case unknown(String)

  var errorDescription: String? {
    switch self {
    case .networkError(let message):
      return "ネットワークエラー: \(message)"
    case .notFound:
      return "アンケートが見つかりませんでした"
    case .invalidData:
      return "データの形式が不正です"
    case .invalidDocumentId:
      return "無効なドキュメントIDです"
    case .unknown(let message):
      return "不明なエラー: \(message)"
    }
  }
}

// MARK: - FirestoreService

/// Firestoreからアンケート情報を取得するサービスクラス
class FirestoreService {

  // MARK: - Singleton

  static let shared = FirestoreService()

  private let db = Firestore.firestore()
  private let collectionName = "surveys"

  private init() {}

  // MARK: - Public Methods

  /// FirestoreのドキュメントIDからアンケート情報を取得する
  /// - Parameter documentId: FirestoreのドキュメントID
  /// - Returns: 取得したアンケート情報
  /// - Throws: FirestoreServiceError
  func fetchSurvey(documentId: String) async throws -> FirestoreSurveyDocument {
    // ドキュメントIDのバリデーション
    guard !documentId.isEmpty else {
      throw FirestoreServiceError.invalidDocumentId
    }

    do {
      // Firestoreからドキュメントを取得
      let docRef = db.collection(collectionName).document(documentId)
      let document = try await docRef.getDocument()

      // ドキュメントが存在するか確認
      guard document.exists else {
        throw FirestoreServiceError.notFound
      }

      // ドキュメントデータを取得
      guard let data = document.data() else {
        throw FirestoreServiceError.invalidData
      }

      // FirestoreSurveyDocumentに変換
      let survey = try parseSurveyDocument(documentId: documentId, data: data)
      return survey

    } catch let error as FirestoreServiceError {
      throw error
    } catch {
      throw FirestoreServiceError.networkError(error.localizedDescription)
    }
  }

  /// FirestoreのドキュメントIDからアンケート情報を取得する(コールバック版)
  /// - Parameters:
  ///   - documentId: FirestoreのドキュメントID
  ///   - completion: 取得完了時のコールバック
  func fetchSurvey(
    documentId: String,
    completion: @escaping (Result<FirestoreSurveyDocument, FirestoreServiceError>) -> Void
  ) {
    Task {
      do {
        let survey = try await fetchSurvey(documentId: documentId)
        await MainActor.run {
          completion(.success(survey))
        }
      } catch let error as FirestoreServiceError {
        await MainActor.run {
          completion(.failure(error))
        }
      } catch {
        await MainActor.run {
          completion(.failure(.unknown(error.localizedDescription)))
        }
      }
    }
  }

  // MARK: - Private Methods

  /// FirestoreドキュメントデータをFirestoreSurveyDocumentに変換
  private func parseSurveyDocument(documentId: String, data: [String: Any]) throws
    -> FirestoreSurveyDocument
  {
    // titleを取得
    guard let title = data["title"] as? String else {
      throw FirestoreServiceError.invalidData
    }

    // questionsを取得
    guard let questionsData = data["questions"] as? [[String: Any]] else {
      throw FirestoreServiceError.invalidData
    }

    // questionsをパース
    let questions = try questionsData.map { questionData in
      try parseQuestion(data: questionData)
    }

    // createdAt、updatedAtを取得(オプショナル)
    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

    return FirestoreSurveyDocument(
      id: documentId,
      title: title,
      questions: questions,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  /// Firestore質問データをFirestoreQuestionに変換
  private func parseQuestion(data: [String: Any]) throws -> FirestoreQuestion {
    // indexを取得
    guard let index = data["index"] as? Int else {
      throw FirestoreServiceError.invalidData
    }

    // typeを取得
    guard let typeString = data["type"] as? String,
      let type = FirestoreQuestionType(rawValue: typeString)
    else {
      throw FirestoreServiceError.invalidData
    }

    // titleを取得(オプショナル)
    let title = data["title"] as? String

    // optionsを取得(オプショナル)
    let options = data["options"] as? [String]

    // infoFieldsを取得(オプショナル)
    var infoFields: InfoFields? = nil
    if let infoFieldsData = data["infoFields"] as? [String: Any] {
      infoFields = InfoFields(
        furigana: infoFieldsData["furigana"] as? Bool,
        name: infoFieldsData["name"] as? Bool,
        nameWithFurigana: infoFieldsData["nameWithFurigana"] as? Bool,
        email: infoFieldsData["email"] as? Bool,
        phone: infoFieldsData["phone"] as? Bool,
        postalCode: infoFieldsData["postalCode"] as? Bool,
        address: infoFieldsData["address"] as? Bool
      )
    }

    return FirestoreQuestion(
      index: index,
      type: type,
      title: title,
      options: options,
      infoFields: infoFields
    )
  }
}

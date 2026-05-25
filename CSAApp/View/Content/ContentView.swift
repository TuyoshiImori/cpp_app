import SwiftData
import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var auth: AuthService
  @StateObject private var viewModel = ContentViewModel()
  @Environment(\.modelContext) private var modelContext
  @Environment(\.editMode) private var editMode
  @Environment(\.scenePhase) private var scenePhase
  @Query private var items: [Item]
  // View 側で local に持っていた状態は ViewModel に移動済み

  // OCRデバッグ画面表示用の状態
  @State private var isShowingDebugOCR: Bool = false
  // Firestoreから取得したアンケート一覧
  @State private var firestoreSurveys: [FirestoreSurveyDocument] = []
  @State private var isLoadingSurveys: Bool = false
  // 表示用に変換したアイテム一覧（AccordionItem UIで利用）
  @State private var displayItems: [Item] = []

  // MARK: - Helper Methods

  /// FirestoreSurveyDocumentをItemに変換するヘルパー関数
  private func convertFirestoreSurveyToItem(_ survey: FirestoreSurveyDocument) -> Item {
    // FirestoreQuestionをQuestionTypeに変換
    let questionTypes: [QuestionType] = survey.questions.map { question in
      let questionTitle = question.title ?? ""  // 設問タイトルを取得

      switch question.type {
      case .single:
        return .single(questionTitle, question.options ?? [])
      case .multiple:
        return .multiple(questionTitle, question.options ?? [])
      case .text:
        return .text(questionTitle)
      case .info:
        // InfoFieldsをQuestionType.InfoFieldの配列に変換
        var infoFields: [QuestionType.InfoField] = []
        if let fields = question.infoFields {
          if fields.furigana == true { infoFields.append(.furigana) }
          if fields.name == true { infoFields.append(.name) }
          if fields.nameWithFurigana == true { infoFields.append(.nameKana) }
          if fields.email == true { infoFields.append(.email) }
          if fields.phone == true { infoFields.append(.tel) }
          if fields.postalCode == true { infoFields.append(.zip) }
          if fields.address == true { infoFields.append(.address) }
        }
        return .info(questionTitle, infoFields)
      }
    }

    // optionTextsを構築（各設問の選択肢）
    let optionTexts: [[String]] = survey.questions.map { question in
      question.options ?? []
    }

    return Item(
      timestamp: survey.createdAt ?? Date(),
      questionTypes: questionTypes,
      surveyID: survey.id,
      title: survey.title,
      isNew: true,  // Firestoreから取得したアイテムは新規扱い
      optionTexts: optionTexts,
      scanResults: [],
      answerTexts: [],
      questionImageData: []
    )
  }

  var body: some View {
    if !auth.isSignedIn {
      LoginView()
    } else {
      mainContent
    }
  }

  @ViewBuilder
  private var mainContent: some View {
    NavigationStack(
      path: Binding(
        get: { viewModel.navigationPath },
        set: { viewModel.navigationPath = $0 }
      )
    ) {
      Group {
        if isLoadingSurveys {
          ProgressView("読み込み中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayItems.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "doc.text")
              .font(.system(size: 48))
              .foregroundColor(.secondary.opacity(0.4))
            Text("アンケートがありません")
              .font(.headline)
              .foregroundColor(.secondary)
            Text("ブラウザでアンケートを作成して\nクラウドに保存してください")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ItemsListView(
            viewModel: viewModel,
            items: displayItems,
            expandedRowIDs: Binding(
              get: { viewModel.expandedRowIDs },
              set: { viewModel.expandedRowIDs = $0 }
            ),
            modelContext: nil,
            onTap: { item, _ in
              if let survey = firestoreSurveys.first(where: { $0.id == item.surveyID }) {
                openSurvey(survey)
              }
            },
            onEdit: { _, _ in }
          )
          .refreshable { await loadSurveys() }
        }
      }
      .task { await loadSurveys() }
      .navigationDestination(for: String.self) { destination in
        if destination == "CameraView" {
          CameraView(
            image: Binding(
              get: { viewModel.selectedImage }, set: { viewModel.selectedImage = $0 }),
            item: viewModel.currentItem)
        }
      }
      // navigationPath の変更による副作用はここでは扱わない。
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          HStack(spacing: 8) {
            // ユーザーメニュー（ログアウト）
            Menu {
              Button(role: .destructive) {
                try? auth.signOut()
              } label: {
                Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
              }
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "person.crop.circle")
                Text(auth.displayName)
                  .font(.caption)
                  .lineLimit(1)
              }
            }
            // デバッグ画面ボタン
            Button(action: {
              isShowingDebugOCR = true
            }) {
              Image(systemName: "wrench.and.screwdriver")
            }
          }
        }
      }
    }
    // OCRデバッグ画面をシートで表示
    .sheet(isPresented: $isShowingDebugOCR) {
      DebugOCRView()
    }
    // アプリがフォアグラウンドから離れたときに編集状態を初期化
    .onChange(of: scenePhase) { (newPhase: ScenePhase) in
      if newPhase == .background || newPhase == .inactive {
        viewModel.clearEditingState()
        editMode?.wrappedValue = .inactive
      }
    }
  }

  // MARK: - Private Methods

  private func loadSurveys() async {
    guard let uid = auth.uid else { return }
    isLoadingSurveys = firestoreSurveys.isEmpty
    do {
      firestoreSurveys = try await FirestoreService.shared.fetchUserSurveys(uid: uid)
      displayItems = firestoreSurveys.map { convertFirestoreSurveyToItem($0) }
    } catch {
      print("サーベイ取得エラー: \(error)")
    }
    isLoadingSurveys = false
  }

  private func openSurvey(_ survey: FirestoreSurveyDocument) {
    // 既存のItemがあればスキャン結果を保持したまま再利用
    let targetItem: Item
    if let existing = items.first(where: { $0.surveyID == survey.id }) {
      targetItem = existing
    } else {
      let newItem = convertFirestoreSurveyToItem(survey)
      modelContext.insert(newItem)
      try? modelContext.save()
      targetItem = newItem
    }
    viewModel.currentItem = targetItem
    viewModel.selectedImage = nil
    viewModel.navigationPath.append("CameraView")
  }
}

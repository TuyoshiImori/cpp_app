import SwiftData
import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = ContentViewModel()
  @Environment(\.modelContext) private var modelContext
  @Environment(\.editMode) private var editMode
  @Environment(\.scenePhase) private var scenePhase
  @Query private var items: [Item]
  // View 側で local に持っていた状態は ViewModel に移動済み

  // QR画面表示用の状態
  @State private var isShowingQrView: Bool = false

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
      confidenceScores: [],
      answerTexts: [],
      questionImageData: []
    )
  }

  var body: some View {
    NavigationStack(
      path: Binding(
        get: { viewModel.navigationPath },
        set: { viewModel.navigationPath = $0 }
      )
    ) {
      ZStack {
        // アイテム一覧部分を分割したサブビューへ移譲
        ItemsListView(
          viewModel: viewModel,
          items: items,
          expandedRowIDs: Binding(
            get: { viewModel.expandedRowIDs }, set: { viewModel.expandedRowIDs = $0 }),
          modelContext: modelContext,
          onTap: { item, rowID in
            // タップ時の動作は引き続き ContentView が保持
            viewModel.handleItemTapped(item, rowID: rowID, modelContext: modelContext)
            // 選択されたアイテムを currentItem にセットして CameraView に遷移
            viewModel.currentItem = item
            // 直前の選択画像があればクリアしておく
            viewModel.selectedImage = nil
            // プッシュ遷移でCameraViewに移動
            viewModel.navigationPath.append("CameraView")
          },
          onEdit: { item, rowID in
            // 編集ダイアログを表示する準備
            viewModel.editTargetItem = item
            viewModel.editTargetRowID = rowID
            viewModel.editTitleText = item.title
            viewModel.isShowingEditDialog = true
          }
        )

        // フローティングボタン（右下に配置）- ItemsListViewにのみ表示
        VStack {
          Spacer()
          HStack {
            Spacer()
            Button(action: {
              isShowingQrView = true
            }) {
              Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
          }
        }
      }
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
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            viewModel.toggleEditMode()
            if viewModel.isEditing { viewModel.slideAllItemsForEdit(items: items) }
          }) { Text(viewModel.isEditing ? "完了" : "編集") }
        }
      }
      // バナー表示を分離したコンポーネントで表示
      .overlay(BannerView(show: viewModel.showBanner, title: viewModel.bannerTitle))
      // 編集タイトル用の中央ダイアログ（共通コンポーネント InputDialog を使用）
      .overlay {
        InputDialog(
          isPresented: Binding(
            get: { viewModel.isShowingEditDialog }, set: { viewModel.isShowingEditDialog = $0 }),
          inputText: Binding(
            get: { viewModel.editTitleText }, set: { viewModel.editTitleText = $0 }),
          onSubmit: { newTitle in
            if let target = viewModel.editTargetItem {
              target.title = newTitle
              try? modelContext.save()
              viewModel.dataVersion = UUID()
            }
          },
          dialogTitle: "タイトルを編集",
          placeholder: "タイトル",
          cancelButtonText: "キャンセル",
          submitButtonText: "保存"
        )
      }
    }
    // QR画面をフルスクリーンで表示
    .fullScreenCover(isPresented: $isShowingQrView) {
      QrView(onSurveyFetched: { survey in
        // 取得したアンケート情報をItemに変換して保存
        let newItem = convertFirestoreSurveyToItem(survey)
        modelContext.insert(newItem)
        try? modelContext.save()

        // ViewModelにも保存して表示用に使用
        viewModel.fetchedSurvey = survey
      })
    }
    // アプリがフォアグラウンドから離れたときに編集状態を初期化
    .onChange(of: scenePhase) { (newPhase: ScenePhase) in
      if newPhase == .background || newPhase == .inactive {
        // ViewModel 側で ViewModel 管理の状態を初期化
        viewModel.clearEditingState()

        // View 側に残す view-local 状態はなし。ViewModel のプロパティをクリアしているため
        // ここでは EditMode の解放だけを行う
        editMode?.wrappedValue = .inactive
      }
    }
  }
}

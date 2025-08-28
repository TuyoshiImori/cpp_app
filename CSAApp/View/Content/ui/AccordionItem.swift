import Combine
import Foundation
import SwiftData
import SwiftUI

// コンパイル時の型チェック負荷を軽減するため、ContentView から切り出しました。
struct AccordionItem: View {
  let item: Item
  let rowID: String
  @Binding var expandedRowIDs: Set<String>
  @Binding var newRowIDs: Set<String>
  let viewModel: ContentViewModel
  let modelContext: ModelContext?
  let onTap: () -> Void

  // ViewModel にロジックを委譲 (ContentViewModel に統合した AccordionItem 用 VM を利用)
  private var vm: ContentViewModel.AccordionItemVM {
    ContentViewModel.AccordionItemVM(item: item, rowID: rowID)
  }

  // スライド削除機能用の状態
  @State private var dragOffset: CGFloat = 0
  @State private var isDragging: Bool = false

  // 削除時に slideOffset によるアニメーションを一時的に無効化するフラグ
  @State private var suppressSlideAnimation: Bool = false

  // 削除ボタンの幅
  private let deleteButtonWidth: CGFloat = 60

  // ローカルで削除アニメーション用のオフセット（deleteButtonView と mainContentView に適用）
  @State private var deleteAnimationOffset: CGFloat = 0

  var body: some View {
    let isExpanded = vm.isExpanded(in: expandedRowIDs)
    let slideOffset = vm.getSlideOffset(from: viewModel.slideOffsets)

    ZStack(alignment: .leading) {
      deleteButtonView
        .offset(x: deleteAnimationOffset)
      mainContentView(isExpanded: isExpanded)
        .offset(x: slideOffset + dragOffset + deleteAnimationOffset)
        // 手動スワイプを無効化: 編集モードの切り替え(Editボタン)でのみスライド状態を変更する
        // 削除アクションのときだけアニメーションを抑制できるように制御
        .animation(
          suppressSlideAnimation ? nil : .spring(response: 0.4, dampingFraction: 0.8),
          value: slideOffset)
    }
    .clipped()
    .cornerRadius(10)
    .padding(.horizontal, 0)
    .padding(.vertical, 0)
  }

  @ViewBuilder
  private var deleteButtonView: some View {
    let swipeState = vm.getSwipeState(from: viewModel.swipeStates)
    if viewModel.isEditing || swipeState == .revealed {
      HStack {
        deleteButton
        Spacer()
      }
      .transition(.move(edge: .leading))
    }
  }

  private var deleteButton: some View {
    GeometryReader { geo in
      Button(action: {
        // 削除アニメーション用オフセットを親幅分右へアニメーション
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
          deleteAnimationOffset = geo.size.width
        }

        // アニメーション完了後に ViewModel の非アニメーション削除を呼ぶ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
          // 削除時に slideOffset のアニメーションのみ無効化
          suppressSlideAnimation = true

          viewModel.handleSlideDeleteWithoutAnimation(item, modelContext: modelContext)

          // すぐにフラグを戻す
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            suppressSlideAnimation = false
            deleteAnimationOffset = 0
          }
        }
      }) {
        Image(systemName: "trash")
          .foregroundColor(.white)
          .frame(width: deleteButtonWidth, height: nil)
          .frame(maxHeight: .infinity)
          .background(Color.red)
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func mainContentView(isExpanded: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      headerView(isExpanded: isExpanded)
      expandedContentView(isExpanded: isExpanded)
    }
    .background(.background)
    .animation(.easeInOut(duration: 0.25), value: isExpanded)
    // 編集モード中はタップによる画面遷移を無効化
    .onTapGesture {
      guard !viewModel.isEditing else { return }
      onTap()
    }
  }

  @ViewBuilder
  private func headerView(isExpanded: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      // ID
      if !item.surveyID.isEmpty {
        Text("ID: \(item.surveyID)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // タイトル
      if !item.title.isEmpty {
        titleRowView(isExpanded: isExpanded)
      }

      // 追加した日時
      Text(vm.formattedTimestamp(item.timestamp))
        .font(.subheadline)
        .fontWeight(.light)
        .foregroundColor(.secondary)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
    .zIndex(2)
    .animation(nil, value: isExpanded)
  }

  @ViewBuilder
  private func titleRowView(isExpanded: Bool) -> some View {
    HStack(alignment: .center, spacing: 8) {
      titleText
      newBadge
      expandButton(isExpanded: isExpanded)
    }
  }

  private var titleText: some View {
    Text(item.title)
      .font(.title3)
      .fontWeight(.semibold)
      .lineLimit(2)
      .layoutPriority(1)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var newBadge: some View {
    Text("NEW")
      .font(.caption2)
      .bold()
      .foregroundColor(.white)
      .padding(.vertical, 4)
      .padding(.horizontal, 8)
      .background(Color.red)
      .cornerRadius(6)
      .frame(minWidth: 44, alignment: .center)
      .opacity(vm.isNew(in: newRowIDs) ? 1.0 : 0.0)
  }

  @ViewBuilder
  private func expandButton(isExpanded: Bool) -> some View {
    if !item.questionTypes.isEmpty {
      Button(action: {
        withAnimation(.easeInOut(duration: 0.25)) {
          vm.toggleExpanded(&expandedRowIDs)
        }
      }) {
        Image(systemName: vm.chevronImageName(isExpanded: isExpanded))
          .foregroundColor(vm.chevronForegroundColor(isExpanded: isExpanded))
          .imageScale(.medium)
          .frame(width: 36, height: 36)
          .background(vm.chevronBackgroundColor(isExpanded: isExpanded))
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
              Color.blue.opacity(0.15), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
    }
  }

  @ViewBuilder
  private func expandedContentView(isExpanded: Bool) -> some View {
    if !item.questionTypes.isEmpty && isExpanded {
      VStack(spacing: 8) {
        ForEach(Array(item.questionTypes.enumerated()), id: \.0) { index, questionType in
          HStack(alignment: .top) {
            Spacer().frame(width: 16)
            switch questionType {
            case .single(let question, let options):
              Image(systemName: "checkmark.circle").foregroundColor(.blue)
              VStack(alignment: .leading) {
                Text("\(question)")
                  .fixedSize(horizontal: false, vertical: true)
                Text(options.joined(separator: ","))
                  .font(.subheadline).foregroundColor(.gray)
                  .lineLimit(1).truncationMode(.tail)
              }
            case .multiple(let question, let options):
              Image(systemName: "list.bullet").foregroundColor(.green)
              VStack(alignment: .leading) {
                Text("\(question)")
                  .fixedSize(horizontal: false, vertical: true)
                Text(options.joined(separator: ","))
                  .font(.subheadline).foregroundColor(.gray)
                  .lineLimit(1).truncationMode(.tail)
              }
            case .text(let question):
              Image(systemName: "textformat").foregroundColor(.orange)
              Text("\(question)")
                .fixedSize(horizontal: false, vertical: true)
            case .info(let question, let fields):
              Image(systemName: "person.crop.circle").foregroundColor(.purple)
              VStack(alignment: .leading) {
                Text("\(question)")
                  .fixedSize(horizontal: false, vertical: true)
                Text(fields.map { $0.displayName }.joined(separator: ","))
                  .font(.subheadline)
                  .foregroundColor(.gray).lineLimit(1).truncationMode(.tail)
              }
            }
            Spacer()
          }
        }
      }
      .padding(.top, 12)
      .padding(.bottom, 12)
      .zIndex(0)
      .transition(.move(edge: .top).combined(with: .opacity))
      .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
  }

  private var swipeGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        // 編集モードでない場合はユーザー操作によるドラッグを無視する
        guard viewModel.isEditing else { return }
        let translation = value.translation.width
        isDragging = true

        // 左方向のドラッグのみ許可（削除ボタンを表示するため）
        if translation < 0 {
          dragOffset = max(translation, -deleteButtonWidth)
        } else if vm.getSwipeState(from: viewModel.swipeStates) == .revealed {
          // 既に削除ボタンが表示されている場合は右方向のドラッグも許可
          dragOffset = min(translation, 0)
        }
      }
      .onEnded { value in
        // 編集モードでない場合はユーザー操作によるドラッグを無視する
        guard viewModel.isEditing else { return }
        isDragging = false
        let translation = value.translation.width
        let velocity = value.velocity.width

        // スワイプの閾値を判定
        let threshold = deleteButtonWidth / 2
        let shouldReveal = translation < -threshold || velocity < -500

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
          if shouldReveal {
            // 削除ボタンを表示
            viewModel.setSlideState(for: rowID, offset: -deleteButtonWidth, state: .revealed)
          } else {
            // 元の位置に戻す
            viewModel.setSlideState(for: rowID, offset: 0, state: .normal)
          }
          dragOffset = 0
        }
      }
  }
}

import Combine
import Foundation
import SwiftData
import SwiftUI

// コンパイル時の型チェック負荷を軽減するため、ContentView から切り出しました。
struct AccordionItem: View {
  let item: Item
  let rowID: String
  // リスト内で先頭・末尾を判定して角丸を制御
  let isFirst: Bool
  let isLast: Bool
  @Binding var expandedRowIDs: Set<String>
  @Binding var newRowIDs: Set<String>
  let viewModel: ContentViewModel
  let modelContext: ModelContext?
  let onTap: () -> Void
  let onEdit: (Item, String) -> Void

  @Environment(\.colorScheme) private var colorScheme

  private var cardBackground: Color {
    // 共通のカード背景ユーティリティを利用
    CardBackground.color(for: colorScheme)
  }

  // ViewModel にロジックを委譲 (ContentViewModel に統合した AccordionItem 用 VM を利用)
  private var vm: ContentViewModel.AccordionItemVM {
    ContentViewModel.AccordionItemVM(item: item, rowID: rowID)
  }

  // スライド削除機能用の状態は ViewModel が保持する
  private var actionButtonWidth: CGFloat { viewModel.actionButtonWidth }
  private var totalActionButtonsWidth: CGFloat { viewModel.totalActionButtonsWidth }

  // per-row UI state を ViewModel 側から参照/更新するための computed properties
  private var dragOffset: CGFloat { viewModel.getDragOffset(for: rowID) }
  private var isDragging: Bool { viewModel.isDragging(for: rowID) }
  private var suppressSlideAnimation: Bool { viewModel.isSuppressSlideAnimation(for: rowID) }
  private var deleteAnimationOffset: CGFloat { viewModel.getDeleteAnimationOffset(for: rowID) }

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
    // カード背景：ダークモード時は薄い黒、ライトはシステム背景
    .background(cardBackground)
    .clipShape(RoundedCorners(radius: 10, corners: cornersToRound()))
    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    // 設定アプリ風の区切り線を各アイテム下部に表示（左にインセットを入れる）
    .overlay(
      VStack {
        Spacer()
        Rectangle()
          .fill(Color.secondary.opacity(0.25))
          .frame(height: 0.5)
          .padding(.leading, 16)
      }
    )
    .padding(.horizontal, 0)
    .padding(.vertical, 0)
  }

  // 角丸を適用する角を決定
  private func cornersToRound() -> Corners {
    if isFirst && isLast { return .all }
    if isFirst { return [.topLeft, .topRight] }
    if isLast { return [.bottomLeft, .bottomRight] }
    return []
  }

  // 独自の OptionSet で角を表現
  struct Corners: OptionSet {
    let rawValue: Int
    static let topLeft = Corners(rawValue: 1 << 0)
    static let topRight = Corners(rawValue: 1 << 1)
    static let bottomLeft = Corners(rawValue: 1 << 2)
    static let bottomRight = Corners(rawValue: 1 << 3)
    static let all: Corners = [.topLeft, .topRight, .bottomLeft, .bottomRight]
  }

  // カスタム Shape: 指定した角だけを丸める（UIKit 非依存）
  struct RoundedCorners: Shape {
    var radius: CGFloat = 10
    var corners: Corners = []

    func path(in rect: CGRect) -> Path {
      var path = Path()

      let tl = corners.contains(.topLeft) ? radius : 0
      let tr = corners.contains(.topRight) ? radius : 0
      let bl = corners.contains(.bottomLeft) ? radius : 0
      let br = corners.contains(.bottomRight) ? radius : 0

      // start at top-left
      path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
      // top edge
      path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
      // top-right corner
      if tr > 0 {
        path.addArc(
          center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr,
          startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
      }
      // right edge
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
      // bottom-right corner
      if br > 0 {
        path.addArc(
          center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br,
          startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
      }
      // bottom edge
      path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
      // bottom-left corner
      if bl > 0 {
        path.addArc(
          center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl,
          startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
      }
      // left edge
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
      // top-left corner
      if tl > 0 {
        path.addArc(
          center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl,
          startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
      }

      path.closeSubpath()
      return path
    }
  }

  @ViewBuilder
  private var deleteButtonView: some View {
    let swipeState = vm.getSwipeState(from: viewModel.swipeStates)
    if viewModel.isEditing || swipeState == .revealed {
      GeometryReader { geo in
        HStack(spacing: 0) {
          // 編集ボタン（機能未実装）
          Button(action: {
            // 編集ボタン押下時は ContentView 経由でダイアログを表示させる
            onEdit(item, rowID)
          }) {
            Image(systemName: "pencil")
              .foregroundColor(.white)
              .frame(width: actionButtonWidth, height: nil)
              .frame(maxHeight: .infinity)
              .background(Color.blue)
          }
          .buttonStyle(.plain)

          // 削除ボタン（既存処理）
          Button(action: {
            // 削除アニメーション用オフセットを親幅分右へアニメーション
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
              viewModel.setDeleteAnimationOffset(for: rowID, geo.size.width)
            }

            // アニメーション完了後に ViewModel の非アニメーション削除を呼ぶ
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
              // 削除時に slideOffset のアニメーションのみ無効化
              viewModel.setSuppressSlideAnimation(for: rowID, true)

              viewModel.handleSlideDeleteWithoutAnimation(item, modelContext: modelContext)

              // すぐにフラグを戻す
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                viewModel.setSuppressSlideAnimation(for: rowID, false)
                viewModel.setDeleteAnimationOffset(for: rowID, 0)
              }
            }
          }) {
            Image(systemName: "trash")
              .foregroundColor(.white)
              .frame(width: actionButtonWidth, height: nil)
              .frame(maxHeight: .infinity)
              .background(Color.red)
          }
          .buttonStyle(.plain)

          Spacer()
        }
        .transition(.move(edge: .leading))
      }
      .frame(maxWidth: .infinity)
    }
  }

  @ViewBuilder
  private func mainContentView(isExpanded: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      headerView(isExpanded: isExpanded)
      expandedContentView(isExpanded: isExpanded)
    }
    .background(cardBackground)
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
      // ID 一旦コメントアウトして非表示
      // if !item.surveyID.isEmpty {
      //   Text("ID: \(item.surveyID)")
      //     .font(.caption)
      //     .foregroundColor(.secondary)
      // }

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
    .background(cardBackground)
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
      .lineLimit(nil)  // 行数制限を外し、必要に応じて改行させる
      .fixedSize(horizontal: false, vertical: true)
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
              QuestionTypeIcon(questionType: questionType)
              VStack(alignment: .leading) {
                Text("\(question)")
                  .fixedSize(horizontal: false, vertical: true)
                Text(options.joined(separator: ","))
                  .font(.subheadline).foregroundColor(.gray)
                  .lineLimit(1).truncationMode(.tail)
              }
            case .multiple(let question, let options):
              QuestionTypeIcon(questionType: questionType)
              VStack(alignment: .leading) {
                Text("\(question)")
                  .fixedSize(horizontal: false, vertical: true)
                Text(options.joined(separator: ","))
                  .font(.subheadline).foregroundColor(.gray)
                  .lineLimit(1).truncationMode(.tail)
              }
            case .text(let question):
              QuestionTypeIcon(questionType: questionType)
              Text("\(question)")
                .fixedSize(horizontal: false, vertical: true)
            case .info(let question, let fields):
              QuestionTypeIcon(questionType: questionType)
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
        viewModel.setIsDragging(true, for: rowID)

        // 左方向のドラッグのみ許可（削除ボタンを表示するため）
        if translation < 0 {
          // 2つ分のボタン幅までドラッグ可能にする
          viewModel.setDragOffset(for: rowID, max(translation, -totalActionButtonsWidth))
        } else if vm.getSwipeState(from: viewModel.swipeStates) == .revealed {
          // 既に削除ボタンが表示されている場合は右方向のドラッグも許可
          viewModel.setDragOffset(for: rowID, min(translation, 0))
        }
      }
      .onEnded { value in
        // 編集モードでない場合はユーザー操作によるドラッグを無視する
        guard viewModel.isEditing else { return }
        viewModel.setIsDragging(false, for: rowID)
        let translation = value.translation.width
        let velocity = value.velocity.width

        // スワイプの閾値を判定
        let threshold = viewModel.swipeRevealThreshold()
        let shouldReveal = translation < -threshold || velocity < -500

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
          if shouldReveal {
            // 削除ボタンを表示
            // 表示は編集 + 削除の2ボタン分をスライドさせる
            viewModel.setSlideState(for: rowID, offset: -totalActionButtonsWidth, state: .revealed)
          } else {
            // 元の位置に戻す
            viewModel.setSlideState(for: rowID, offset: 0, state: .normal)
          }
          viewModel.clearDragOffset(for: rowID)
        }
      }
  }
}

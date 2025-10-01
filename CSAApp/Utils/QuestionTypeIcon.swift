import Foundation
import SwiftUI

// QuestionType がプロジェクト内で定義されていることを前提に、
// より型安全にアイコンを選択する実装に変更しました。
// 受け取る型は `QuestionType?` です。
public struct QuestionTypeIcon: View {
  public let questionType: QuestionType?
  public let size: Font

  public init(questionType: QuestionType? = nil, size: Font = .title2) {
    self.questionType = questionType
    self.size = size
  }

  public var body: some View {
    let (iconName, iconColor) = resolveIcon(from: questionType)

    Image(systemName: iconName)
      .foregroundColor(iconColor)
      .font(size)
  }

  private func resolveIcon(from qt: QuestionType?) -> (String, Color) {
    guard let qt = qt else { return ("dot.circle", .blue) }

    switch qt {
    case .single(_, _):
      return ("checkmark.circle", .blue)
    case .multiple(_, _):
      return ("list.bullet", .green)
    case .text(_):
      return ("textformat", .orange)
    case .info(_, _):
      return ("person.crop.circle", .purple)
    }
  }
}

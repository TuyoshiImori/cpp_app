import SwiftUI

struct QuestionTypeSelectionView: View {
  @Binding var selectedQuestionTypes: [QuestionType]
  var onComplete: () -> Void

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("設問タイプを選択")) {
          Button(action: {
            selectedQuestionTypes.append(.single([]))
          }) {
            HStack {
              Image(systemName: "checkmark.circle")
                .foregroundColor(.blue)
              Text("単数回答を追加")
            }
          }
          Button(action: {
            selectedQuestionTypes.append(.multiple([]))
          }) {
            HStack {
              Image(systemName: "list.bullet")
                .foregroundColor(.green)
              Text("複数回答を追加")
            }
          }
          Button(action: {
            selectedQuestionTypes.append(.freeText)
          }) {
            HStack {
              Image(systemName: "textformat")
                .foregroundColor(.orange)
              Text("自由記述を追加")
            }
          }
        }

        Section(header: Text("選択済み設問タイプ")) {
          ForEach(selectedQuestionTypes.indices, id: \.self) { index in
            HStack {
              switch selectedQuestionTypes[index] {
              case .single(let options):
                Image(systemName: "checkmark.circle")
                  .foregroundColor(.blue)
                Text("単数回答: \(options.joined(separator: ","))")
              case .multiple(let options):
                Image(systemName: "list.bullet")
                  .foregroundColor(.green)
                Text("複数回答: \(options.joined(separator: ","))")
              case .freeText:
                Image(systemName: "textformat")
                  .foregroundColor(.orange)
                Text("自由記述")
              }
              Spacer()
              Button(action: {
                selectedQuestionTypes.remove(at: index)
              }) {
                Image(systemName: "trash")
                  .foregroundColor(.red)
              }
            }
          }
        }
      }
      .navigationTitle("設問タイプを選択")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("完了") {
            onComplete()
          }
        }
      }
    }
  }
}

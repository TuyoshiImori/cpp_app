import SwiftUI

// コンパイル時の型チェック負荷を軽減するため、ContentView から切り出しました。
struct AccordionItem: View {
  let item: Item
  let rowID: String
  @Binding var expandedRowIDs: Set<String>
  @Binding var newRowIDs: Set<String>
  let onTap: () -> Void

  private static let timestampFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP_POSIX")
    f.dateFormat = "yyyy/M/d H:mm"
    return f
  }()

  var body: some View {
    let isExpanded = expandedRowIDs.contains(rowID)

    VStack(alignment: .leading) {
      // 常に表示されるヘッダ領域（ID/タイトル/タイムスタンプ）
      VStack(alignment: .leading, spacing: 6) {
        // ID
        if !item.surveyID.isEmpty {
          Text("ID: \(item.surveyID)")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        if !item.title.isEmpty {
          HStack(alignment: .center, spacing: 8) {
            // タイトル
            Text(item.title)
              .font(.title3)
              .fontWeight(.semibold)
              .lineLimit(2)
              .layoutPriority(1)
              .frame(maxWidth: .infinity, alignment: .leading)

            // Newバッジ
            Text("NEW")
              .font(.caption2)
              .bold()
              .foregroundColor(.white)
              .padding(.vertical, 4)
              .padding(.horizontal, 8)
              .background(Color.red)
              .cornerRadius(6)
              .frame(minWidth: 44, alignment: .center)
              .opacity((newRowIDs.contains(rowID) || item.isNew) ? 1.0 : 0.0)

            if !item.questionTypes.isEmpty {
              let isExpanded = expandedRowIDs.contains(rowID)
              Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                  if isExpanded {
                    expandedRowIDs.remove(rowID)
                  } else {
                    expandedRowIDs.insert(rowID)
                  }
                }
              }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                  .foregroundColor(isExpanded ? .white : .blue)
                  .imageScale(.medium)
                  .frame(width: 36, height: 36)
                  .background(isExpanded ? Color.blue : Color.blue.opacity(0.08))
                  .cornerRadius(8)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15), lineWidth: 1)
                  )
              }
              .buttonStyle(.plain)
              .contentShape(Rectangle())
            }
          }
        }

        Text(AccordionItem.timestampFormatter.string(from: item.timestamp))
          .font(.subheadline)
          .fontWeight(.light)
          .foregroundColor(.secondary)
      }
      .padding(12)
      // ヘッダは横幅いっぱいに広げ、システム背景で覆って透けないようにする
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(UIColor.systemBackground))
      .zIndex(2)  // ヘッダを展開コンテンツより前面に表示
      .animation(nil, value: isExpanded)

      // 展開コンテンツ：常にビュー階層に残すが、折りたたむ際は
      // maxHeight = 0 と clipped を用いてレイアウトを押し下げ、
      // 固有の高さを測定しないようにする。
      if !item.questionTypes.isEmpty {
        // 条件付きレンダリングを使い、折りたたまれた行は高さ0になるようにする。
        if isExpanded {
          Spacer().frame(height: 12)

          VStack(spacing: 8) {
            ForEach(item.questionTypes, id: \.self) { questionType in
              HStack(alignment: .top) {
                Spacer().frame(width: 16)
                switch questionType {
                case .single(let question, let options):
                  Image(systemName: "checkmark.circle").foregroundColor(.blue)
                  VStack(alignment: .leading) {
                    Text("\(question)")
                      .fixedSize(horizontal: false, vertical: true)
                      .animation(nil, value: isExpanded)
                    Text(options.joined(separator: ","))
                      .font(.subheadline).foregroundColor(.gray)
                      .lineLimit(1).truncationMode(.tail)
                      .animation(nil, value: isExpanded)
                  }
                case .multiple(let question, let options):
                  Image(systemName: "list.bullet").foregroundColor(.green)
                  VStack(alignment: .leading) {
                    Text("\(question)")
                      .fixedSize(horizontal: false, vertical: true)
                      .animation(nil, value: isExpanded)
                    Text(options.joined(separator: ","))
                      .font(.subheadline).foregroundColor(.gray)
                      .lineLimit(1).truncationMode(.tail)
                      .animation(nil, value: isExpanded)
                  }
                case .text(let question):
                  Image(systemName: "textformat").foregroundColor(.orange)
                  Text("\(question)")
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(nil, value: isExpanded)
                case .info(let question, let fields):
                  Image(systemName: "person.crop.circle").foregroundColor(.purple)
                  VStack(alignment: .leading) {
                    Text("\(question)")
                      .fixedSize(horizontal: false, vertical: true)
                      .animation(nil, value: isExpanded)
                    Text(fields.map { $0.displayName }.joined(separator: ","))
                      .font(.subheadline)
                      .foregroundColor(.gray).lineLimit(1).truncationMode(.tail)
                      .animation(nil, value: isExpanded)
                  }
                }
                Spacer()
              }
            }
          }
          .zIndex(0)
          .transition(.move(edge: .top).combined(with: .opacity))
          .animation(.easeInOut(duration: 0.25), value: isExpanded)
        }
      }
    }
    // 展開／折りたたみ時にレイアウトの変化（コンテンツを押し下げる）をアニメーションする
    .animation(.easeInOut(duration: 0.25), value: isExpanded)
    .background(Color(UIColor.systemBackground))
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10).stroke(
        Color(UIColor.separator).opacity(0.6), lineWidth: 0.5)
    )
    .onTapGesture(perform: onTap)
    .padding(.horizontal, 0)
    .padding(.vertical, 4)
  }
}

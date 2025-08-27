import SwiftData
import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = ContentViewModel()
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [Item]
  // 新規追加を示すための一時的な rowID 集合（NEW バッジ表示用）
  @State private var newRowIDs: Set<String> = []
  // 各行の設問表示を折りたたむ/展開するための状態
  @State private var expandedRowIDs: Set<String> = []
  @State private var showBanner: Bool = false
  @State private var bannerTitle: String = ""
  @State private var isPresentedCameraView = false
  @State private var image: UIImage?
  @State private var currentItem: Item?

  // (手動での設問設定は廃止) ダイアログ関連の状態を削除

  // 選択されたアイテムの画像を保持する状態
  @State private var selectedImage: UIImage?

  // タイムスタンプを安定して表示するための DateFormatter
  private static let timestampFormatter: DateFormatter = {
    let f = DateFormatter()
    // 日本表記を固定（再現性のあるフォーマット）
    f.locale = Locale(identifier: "ja_JP_POSIX")
    f.dateFormat = "yyyy/M/d H:mm"
    return f
  }()

  var body: some View {
    ZStack {
      NavigationSplitView {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(items.sorted(by: { $0.timestamp > $1.timestamp })) { item in
                let rowID: String =
                  item.surveyID.isEmpty
                  ? String(item.timestamp.timeIntervalSince1970) : item.surveyID
                VStack(alignment: .leading) {
                  Group {
                    // ID
                    if !item.surveyID.isEmpty {
                      Text("ID: \(item.surveyID)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    // タイトル
                    if !item.title.isEmpty {
                      // HStack を中央揃えにして、バッジは常にレイアウト上に存在させる（opacity で表示制御）
                      HStack(alignment: .center, spacing: 8) {
                        // タイトルは優先的に幅を確保する
                        Text(item.title)
                          .font(.title3)
                          .fontWeight(.semibold)
                          .lineLimit(2)
                          .layoutPriority(1)
                          .frame(maxWidth: .infinity, alignment: .leading)

                        // NEW バッジ（折りたたみボタンの左に配置）
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

                        // 展開/折りたたみボタン（右端に配置）
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
                                RoundedRectangle(cornerRadius: 8)
                                  .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                              )
                          }
                          .buttonStyle(.plain)
                          .contentShape(Rectangle())
                          .accessibilityLabel(isExpanded ? "設問を折りたたむ" : "設問を展開する")
                        }
                      }
                    }

                    // タイムスタンプ（常に "yyyy/M/d H:mm" 形式で表示）
                    Text(Self.timestampFormatter.string(from: item.timestamp))
                      .font(.subheadline)
                      .fontWeight(.light)
                      .foregroundColor(.secondary)
                  }
                  .animation(nil, value: expandedRowIDs.contains(rowID))

                  // タイムスタンプと設問の間にスペースを挿入（区切り線を除去して余白のみ）
                  if expandedRowIDs.contains(rowID) && !item.questionTypes.isEmpty {
                    Spacer().frame(height: 12)

                    // 設問（展開時のみ表示）
                    ForEach(item.questionTypes, id: \.self) { questionType in
                      HStack(alignment: .top) {
                        // 左側に小さなインデントを付ける
                        Spacer().frame(width: 16)
                        switch questionType {
                        case .single(let question, let options):
                          Image(systemName: "checkmark.circle")
                            .foregroundColor(.blue)
                          VStack(alignment: .leading) {
                            Text("\(question)")
                            Text(options.joined(separator: ","))
                              .font(.subheadline)
                              .foregroundColor(.gray)
                              .lineLimit(1)
                              .truncationMode(.tail)
                          }
                        case .multiple(let question, let options):
                          Image(systemName: "list.bullet")
                            .foregroundColor(.green)
                          VStack(alignment: .leading) {
                            Text("\(question)")
                            Text(options.joined(separator: ","))
                              .font(.subheadline)
                              .foregroundColor(.gray)
                              .lineLimit(1)
                              .truncationMode(.tail)
                          }
                        case .text(let question):
                          Image(systemName: "textformat")
                            .foregroundColor(.orange)
                          Text("\(question)")
                        case .info(let question, let fields):
                          Image(systemName: "person.crop.circle")
                            .foregroundColor(.purple)
                          VStack(alignment: .leading) {
                            Text("\(question)")
                            Text(fields.map { $0.displayName }.joined(separator: ","))
                              .font(.subheadline)
                              .foregroundColor(.gray)
                              .lineLimit(1)
                              .truncationMode(.tail)
                          }
                        }
                        Spacer()
                      }
                    }
                  }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(rowID)
                .contentShape(Rectangle())
                .onTapGesture {
                  // タップで NEW フラグを消して保存してからカメラ画面へ遷移
                  if item.isNew {
                    item.isNew = false
                    // モデルコンテキストに変更を保存
                    try? modelContext.save()
                  }
                  // バッジ集合もローカルでクリア
                  newRowIDs.remove(rowID)
                  selectedImage = image
                  isPresentedCameraView = true
                }
              }
            }
            .padding()
          }
          .onReceive(NotificationCenter.default.publisher(for: .didInsertSurvey)) { notif in
            guard let info = notif.userInfo else { return }

            // rowID を決定（surveyID を優先、なければ timestamp を文字列化）
            let sid = (info["surveyID"] as? String) ?? ""
            let ts = info["timestamp"] as? TimeInterval
            let targetRowID: String
            if !sid.isEmpty {
              targetRowID = sid
            } else if let ts = ts {
              targetRowID = String(ts)
            } else {
              return
            }

            // まずはどの画面が表示されていても ContentView に戻るように
            // フルスクリーンカバー等が開いていれば閉じる
            DispatchQueue.main.async {
              isPresentedCameraView = false
            }

            // 少し待ってから NEW バッジ表示とスクロールを行う（画面切替アニメーションの完了を待つ）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
              // NEW バッジを表示（集合に追加）
              newRowIDs.insert(targetRowID)

              // バナー表示タイトルをセットして表示（アニメーションで）
              if let t = info["title"] as? String { bannerTitle = t }
              withAnimation(.easeOut(duration: 0.25)) { showBanner = true }

              // スクロール（UI のレイアウトが整うのを待つ）
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                proxy.scrollTo(targetRowID, anchor: .center)
              }

              // バッジは数秒でフェードアウトして集合から削除
              DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                newRowIDs.remove(targetRowID)
                // バナーも隠す
                withAnimation(.easeOut(duration: 0.6)) { showBanner = false }
              }
            }
          }
        }
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
              .tint(.blue)
          }
        }
      } detail: {
        if let image {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 300)
        } else {
          Text("Select an item")
        }
      }

      // Floating action button (常に画面右下に表示される + ボタン)
      EmptyView()
    }
    .fullScreenCover(isPresented: $isPresentedCameraView) {
      CameraView(image: $selectedImage, item: currentItem)  // Itemを渡す
        .ignoresSafeArea()
    }
    // バナー表示
    .overlay(
      Group {
        if showBanner {
          VStack {
            VStack(alignment: .leading, spacing: 6) {
              Text("新しいアンケートが追加されました")
                .foregroundColor(.white)
                .padding(.horizontal)
              Text("\(bannerTitle)")
                .foregroundColor(.white)
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            Spacer()
          }
          .padding()
          .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
    )
  }
}

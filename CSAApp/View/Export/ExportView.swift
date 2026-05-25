import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// スキャン結果を ZIP にパッケージングし Wi-Fi 転送・AirDrop 共有するビュー
struct ExportView: View {
  let item: Item
  let croppedImageSets: [[UIImage]]
  let parsedAnswersSets: [[String]]
  let questionTypes: [QuestionType]

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dismiss) private var dismiss

  @StateObject private var server = LocalHttpServer()
  @State private var exportState: ExportState = .idle
  @State private var shareItems: [Any] = []
  @State private var isSharePresented: Bool = false
  @State private var zipFileURL: URL?

  enum ExportState {
    case idle, preparing, ready, failed(String)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        backgroundColor.ignoresSafeArea()
        ScrollView {
          VStack(spacing: 24) {
            headerCard
            switch exportState {
            case .idle:
              prepareButton
            case .preparing:
              preparingView
            case .ready:
              readyView
            case .failed(let message):
              errorView(message)
            }
          }
          .padding(20)
        }
      }
      .navigationTitle("エクスポート")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("閉じる") {
            server.stop()
            dismiss()
          }
        }
      }
    }
    .sheet(isPresented: $isSharePresented) {
      ActivityView(activityItems: shareItems)
    }
    .onDisappear {
      server.stop()
    }
  }

  // MARK: - Sub-views

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "doc.zipper")
          .font(.title2)
          .foregroundColor(.blue)
        VStack(alignment: .leading, spacing: 2) {
          Text(item.title.isEmpty ? "アンケート結果" : item.title)
            .font(.headline)
          Text("\(croppedImageSets.count) ページ・\(questionTypes.count) 設問")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
      }
    }
    .padding(16)
    .background(cardBackground)
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
  }

  private var prepareButton: some View {
    Button(action: prepareExport) {
      Label("ZIP を作成する", systemImage: "archivebox")
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
    .buttonStyle(.borderedProminent)
    .cornerRadius(12)
  }

  private var preparingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .scaleEffect(1.5)
      Text("ZIP を作成中...")
        .foregroundColor(.secondary)
    }
    .padding(32)
  }

  private var readyView: some View {
    VStack(spacing: 20) {
      // Wi-Fi 転送カード
      if let url = server.serverURL {
        VStack(alignment: .leading, spacing: 12) {
          Label("Wi-Fi 転送", systemImage: "wifi")
            .font(.headline)
          Text("同じ Wi-Fi に接続されたブラウザで以下の URL を開いてください：")
            .font(.subheadline)
            .foregroundColor(.secondary)

          HStack {
            Text(url)
              .font(.system(.caption, design: .monospaced))
              .lineLimit(2)
              .minimumScaleFactor(0.7)
              .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { UIPasteboard.general.string = url }) {
              Image(systemName: "doc.on.doc")
                .foregroundColor(.blue)
            }
          }
          .padding(10)
          .background(Color.secondary.opacity(0.1))
          .cornerRadius(8)

          Text("ブラウザでこの URL を開くと ZIP が自動的にダウンロードされます。")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
      }

      // AirDrop / 共有カード
      VStack(alignment: .leading, spacing: 12) {
        Label("AirDrop・共有", systemImage: "square.and.arrow.up")
          .font(.headline)
        Text("AirDrop・ファイルアプリ・メールなどで送信できます。")
          .font(.subheadline)
          .foregroundColor(.secondary)

        Button(action: { isSharePresented = true }) {
          Label("共有する", systemImage: "square.and.arrow.up")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .cornerRadius(10)
      }
      .padding(16)
      .background(cardBackground)
      .cornerRadius(12)
      .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)

      // 受け取り側の手順案内
      instructionsCard
    }
  }

  private var instructionsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("ブラウザ側の手順", systemImage: "info.circle")
        .font(.headline)
      VStack(alignment: .leading, spacing: 8) {
        stepRow(number: "1", text: "ブラウザで Web アプリを開く")
        stepRow(number: "2", text: "「回答を受け取る」ページに移動する")
        stepRow(number: "3", text: "Wi-Fi 転送または ZIP ファイルをアップロードする")
        stepRow(number: "4", text: "回答内容を確認・編集して CSV 出力する")
      }
    }
    .padding(16)
    .background(cardBackground)
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
  }

  private func stepRow(number: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text(number)
        .font(.caption)
        .bold()
        .foregroundColor(.white)
        .frame(width: 20, height: 20)
        .background(Color.blue)
        .clipShape(Circle())
      Text(text)
        .font(.subheadline)
    }
  }

  private func errorView(_ message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundColor(.red)
      Text("エラーが発生しました")
        .font(.headline)
      Text(message)
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      Button("再試行") { prepareExport() }
        .buttonStyle(.borderedProminent)
    }
    .padding(24)
  }

  // MARK: - Colors

  private var cardBackground: Color { CardBackground.color(for: colorScheme) }
  private var backgroundColor: some View {
    Group {
      if colorScheme == .dark {
        Color.black
      } else {
        Color(UIColor.systemGray6)
      }
    }
  }

  // MARK: - Export logic

  private func prepareExport() {
    exportState = .preparing
    server.stop()

    Task.detached(priority: .userInitiated) {
      do {
        let zipData = try buildZip()
        let url = try saveZipToTemp(zipData)

        await MainActor.run {
          self.zipFileURL = url
          self.shareItems = [url]
          self.server.start(data: zipData, fileName: url.lastPathComponent)
          self.exportState = .ready
        }
      } catch {
        await MainActor.run {
          self.exportState = .failed(error.localizedDescription)
        }
      }
    }
  }

  private func buildZip() throws -> Data {
    let writer = ZipWriter()
    let title = item.title.isEmpty ? "survey" : item.title
    let pageCount = croppedImageSets.count

    // manifest.json
    let manifest: [String: Any] = [
      "version": 1,
      "title": title,
      "pageCount": pageCount,
      "questions": questionTypes.map { qt -> [String: Any] in
        switch qt {
        case .single(let q, let opts):
          return ["type": "single", "question": q, "options": opts]
        case .multiple(let q, let opts):
          return ["type": "multiple", "question": q, "options": opts]
        case .text(let q):
          return ["type": "text", "question": q]
        case .info(let q, let fields):
          return ["type": "info", "question": q, "fields": fields.map { $0.rawValue }]
        }
      },
    ]
    let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
    writer.addFile(data: manifestData, path: "manifest.json")

    // 各ページ
    for (pageIndex, croppedImages) in croppedImageSets.enumerated() {
      let pageFolder = String(format: "page_%03d", pageIndex + 1)
      let answers = pageIndex < parsedAnswersSets.count ? parsedAnswersSets[pageIndex] : []

      // answers.json
      var answersArray: [[String: Any]] = []
      for (qIndex, qt) in questionTypes.enumerated() {
        var entry: [String: Any] = [
          "questionIndex": qIndex,
          "answer": qIndex < answers.count ? answers[qIndex] : "",
        ]
        switch qt {
        case .single(let q, let opts):
          entry["type"] = "single"
          entry["question"] = q
          entry["options"] = opts
        case .multiple(let q, let opts):
          entry["type"] = "multiple"
          entry["question"] = q
          entry["options"] = opts
        case .text(let q):
          entry["type"] = "text"
          entry["question"] = q
        case .info(let q, let fields):
          entry["type"] = "info"
          entry["question"] = q
          entry["fields"] = fields.map { $0.rawValue }
        }
        answersArray.append(entry)
      }
      let answersData = try JSONSerialization.data(
        withJSONObject: answersArray, options: .prettyPrinted)
      writer.addFile(data: answersData, path: "\(pageFolder)/answers.json")

      // 設問画像 q_001.jpg ...
      for (imgIndex, image) in croppedImages.enumerated() {
        if let jpeg = image.jpegData(compressionQuality: 0.82) {
          let imageName = String(format: "q_%03d.jpg", imgIndex + 1)
          writer.addFile(data: jpeg, path: "\(pageFolder)/\(imageName)")
        }
      }
    }

    return writer.finalize()
  }

  private func saveZipToTemp(_ data: Data) throws -> URL {
    let dateStr = DateUtils.formattedDate(Date())
      .replacingOccurrences(of: "/", with: "")
      .replacingOccurrences(of: " ", with: "_")
      .replacingOccurrences(of: ":", with: "")
    let name = "survey_\(dateStr).zip"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try data.write(to: url, options: .atomic)
    return url
  }
}

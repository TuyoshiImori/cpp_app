import PhotosUI
import SwiftUI

struct DebugOCRView: View {
  @StateObject private var viewModel = DebugOCRViewModel()
  @Environment(\.dismiss) private var dismiss
  @State private var isShowingZoom: Bool = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          imagePickerSection
          imagePreviewSection
          ocrRunButton
          if !viewModel.isProcessing && (viewModel.confidence > 0 || !viewModel.recognizedText.isEmpty) {
            resultSection
          }
        }
        .padding()
      }
      .navigationTitle("OCR デバッグ")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("閉じる") { dismiss() }
        }
      }
    }
    .task(id: viewModel.selectedPhotoItem) {
      await viewModel.loadSelectedPhoto()
    }
    .sheet(isPresented: $isShowingZoom) {
      if let image = viewModel.selectedImage {
        NavigationStack {
          ZoomableImageView(image: image)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("画像確認")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black)
            .toolbar {
              ToolbarItem(placement: .navigationBarLeading) {
                Button("閉じる") { isShowingZoom = false }
              }
            }
        }
      }
    }
  }

  // MARK: - Subviews

  private var imagePickerSection: some View {
    HStack(spacing: 12) {
      PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
        Label("画像を選択", systemImage: "photo.on.rectangle")
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(10)
      }

      Button(action: { viewModel.loadSampleImage() }) {
        Label("サンプル", systemImage: "doc.text.image")
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.secondary.opacity(0.2))
          .foregroundColor(.primary)
          .cornerRadius(10)
      }
    }
  }

  @ViewBuilder
  private var imagePreviewSection: some View {
    if let image = viewModel.selectedImage {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
          Image(systemName: "magnifyingglass.circle.fill")
            .font(.title2)
            .foregroundColor(.white)
            .shadow(radius: 2)
            .padding(8)
        }
        .onTapGesture { isShowingZoom = true }
    } else {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.secondary.opacity(0.1))
        .frame(height: 200)
        .overlay(
          VStack(spacing: 8) {
            Image(systemName: "photo")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("画像を選択してください")
              .foregroundColor(.secondary)
          }
        )
    }
  }

  private var ocrRunButton: some View {
    Button(action: {
      Task { await viewModel.runOCR() }
    }) {
      HStack(spacing: 8) {
        if viewModel.isProcessing {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .frame(width: 20, height: 20)
          Text("認識中...")
        } else {
          Image(systemName: "doc.text.viewfinder")
          Text("OCR 実行")
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(
        viewModel.selectedImage == nil || viewModel.isProcessing
          ? Color.gray.opacity(0.4) : Color.green
      )
      .foregroundColor(.white)
      .cornerRadius(10)
    }
    .disabled(viewModel.selectedImage == nil || viewModel.isProcessing)
  }

  private var resultSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Divider()

      Text("認識結果")
        .font(.headline)

      HStack {
        Text("信頼度")
          .foregroundColor(.secondary)
        Spacer()
        Text(String(format: "%.1f%%", viewModel.confidence))
          .fontWeight(.semibold)
          .foregroundColor(ConfidenceColor.color(for: viewModel.confidence))
      }
      .padding()
      .background(Color.secondary.opacity(0.08))
      .cornerRadius(8)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("認識テキスト")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Spacer()
          Button(action: {
            UIPasteboard.general.string = viewModel.recognizedText
          }) {
            Label("コピー", systemImage: "doc.on.doc")
              .font(.caption)
          }
        }

        Text(viewModel.recognizedText.isEmpty ? "（テキストなし）" : viewModel.recognizedText)
          .font(.body.monospaced())
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
          .background(Color.secondary.opacity(0.08))
          .cornerRadius(8)
      }
    }
  }
}

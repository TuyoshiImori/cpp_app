import PhotosUI
import SwiftUI

struct DebugOCRView: View {
  @StateObject private var viewModel = DebugOCRViewModel()
  @Environment(\.dismiss) private var dismiss
  @State private var isShowingZoom: Bool = false
  @State private var isShowingCrop: Bool = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          imagePickerSection
          imagePreviewSection
          if viewModel.selectedImage != nil {
            croppedImageSection
          }
          ocrRunButton
          if !viewModel.isProcessing && !viewModel.recognizedText.isEmpty {
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
    .fullScreenCover(isPresented: $isShowingCrop) {
      if let image = viewModel.selectedImage {
        CropViewControllerWrapper(
          image: image,
          onCrop: { cropped in
            viewModel.setCroppedImage(cropped)
            isShowingCrop = false
          },
          onCancel: {
            isShowingCrop = false
          }
        )
        .ignoresSafeArea()
      }
    }
    .sheet(isPresented: $isShowingZoom) {
      if let image = viewModel.croppedImage ?? viewModel.selectedImage {
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
      VStack(alignment: .leading, spacing: 6) {
        Text("元画像")
          .font(.caption)
          .foregroundColor(.secondary)

        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity)
          .cornerRadius(8)
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
          .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 6) {
              Button(action: { isShowingCrop = true }) {
                Image(systemName: "crop")
                  .font(.callout)
                  .foregroundColor(.white)
                  .padding(7)
                  .background(.ultraThinMaterial)
                  .clipShape(Circle())
              }
              Button(action: { isShowingZoom = true }) {
                Image(systemName: "magnifyingglass.circle.fill")
                  .font(.title2)
                  .foregroundColor(.white)
                  .shadow(radius: 2)
              }
            }
            .padding(8)
          }
      }
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

  @ViewBuilder
  private var croppedImageSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("OCR 対象")
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
        if viewModel.croppedImage != nil {
          Button(action: { viewModel.clearCrop() }) {
            Label("切り取りを解除", systemImage: "xmark.circle")
              .font(.caption)
              .foregroundColor(.red)
          }
        }
      }

      if let cropped = viewModel.croppedImage {
        Image(uiImage: cropped)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity)
          .cornerRadius(8)
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.6), lineWidth: 1.5))
          .overlay(alignment: .bottomTrailing) {
            Button(action: { isShowingZoom = true }) {
              Image(systemName: "magnifyingglass.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .shadow(radius: 2)
                .padding(8)
            }
          }
      } else {
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
          .foregroundColor(.secondary.opacity(0.4))
          .frame(height: 80)
          .overlay(
            Button(action: { isShowingCrop = true }) {
              HStack(spacing: 6) {
                Image(systemName: "crop")
                Text("手書き部分を切り取る")
              }
              .font(.subheadline)
              .foregroundColor(.secondary)
            }
          )
      }
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
          Text(viewModel.croppedImage != nil ? "切り取り部分を OCR" : "画像全体を OCR")
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(
        viewModel.ocrTargetImage == nil || viewModel.isProcessing
          ? Color.gray.opacity(0.4) : Color.green
      )
      .foregroundColor(.white)
      .cornerRadius(10)
    }
    .disabled(viewModel.ocrTargetImage == nil || viewModel.isProcessing)
  }

  private var resultSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Divider()

      Text("認識結果")
        .font(.headline)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("補正対象テキスト")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Spacer()
          Button(action: {
            UIPasteboard.general.string = viewModel.editableText
          }) {
            Label("コピー", systemImage: "doc.on.doc")
              .font(.caption)
          }
        }
        Text("不要な部分を削除して手書き箇所だけ残してください")
          .font(.caption)
          .foregroundColor(.secondary)

        TextEditor(text: $viewModel.editableText)
          .font(.body.monospaced())
          .frame(minHeight: 100)
          .padding(8)
          .background(Color.secondary.opacity(0.08))
          .cornerRadius(8)
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
      }

      Button(action: {
        Task { await viewModel.correctWithAI() }
      }) {
        HStack(spacing: 8) {
          if viewModel.isCorrecting {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .frame(width: 20, height: 20)
            Text("補正中...")
          } else {
            Image(systemName: "sparkles")
            Text("AI で補正")
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
          viewModel.editableText.isEmpty || viewModel.isCorrecting
            ? Color.gray.opacity(0.4) : Color.purple
        )
        .foregroundColor(.white)
        .cornerRadius(10)
      }
      .disabled(viewModel.editableText.isEmpty || viewModel.isCorrecting)

      if let error = viewModel.aiError {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle")
          Text(error)
            .font(.caption)
        }
        .foregroundColor(.red)
        .padding(10)
        .background(Color.red.opacity(0.08))
        .cornerRadius(8)
      }

      if !viewModel.correctedText.isEmpty {
        Divider()

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Image(systemName: "sparkles")
              .foregroundColor(.purple)
            Text("補正結果")
              .font(.subheadline)
              .foregroundColor(.secondary)
            Spacer()
            Button(action: {
              UIPasteboard.general.string = viewModel.correctedText
            }) {
              Label("コピー", systemImage: "doc.on.doc")
                .font(.caption)
            }
          }

          Text(viewModel.correctedText)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.purple.opacity(0.07))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.2)))
        }
      }
    }
  }
}

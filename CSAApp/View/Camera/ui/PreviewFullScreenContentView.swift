import Foundation
import SwiftUI
import Vision

#if canImport(UIKit)
  import UIKit
#endif

/// 分割されたプレビュー全画面表示用の本体ビュー
struct PreviewFullScreenContentView: View {
  @Binding var isPreviewPresented: Bool
  @Binding var previewIndex: Int

  let croppedImageSets: [[UIImage]]
  let parsedAnswersSets: [[String]]
  var viewModel: CameraViewModel? = nil
  let item: Item?
  var onDelete: ((Int) -> Bool)? = nil

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext

  // エクスポート画面の表示状態
  @State private var isExportPresented: Bool = false

  private var previewCardBackground: Color {
    CardBackground.color(for: colorScheme)
  }

  private var previewScreenBackground: some View {
    Group {
      if colorScheme == .dark {
        Color.black.ignoresSafeArea()
      } else {
        #if canImport(UIKit)
          Color(UIColor.systemGray6).ignoresSafeArea()
        #else
          Color(.init(white: 0.95, alpha: 1.0)).ignoresSafeArea()
        #endif
      }
    }
  }

  var body: some View {
    ZStack {
      previewScreenBackground

      // 画像が存在する場合に TabView を表示
      if !croppedImageSets.isEmpty {
        PreviewFullScreenImagesTabView(
          previewIndex: $previewIndex, croppedImageSets: croppedImageSets,
          parsedAnswersSets: parsedAnswersSets, viewModel: viewModel)
      }

      VStack {
        HStack {
          Button(action: { isPreviewPresented = false }) {
            Label("閉じる", systemImage: "xmark")
              .labelStyle(.iconOnly)
              .font(.system(size: 20))
              .padding(.horizontal, 12)
              .padding(.vertical, 12)
              .foregroundColor(ButtonForeground.color(for: colorScheme))
          }
          .glassEffect(.regular.interactive())

          Spacer()

          if item != nil {
            Button(action: {
              isExportPresented = true
            }) {
              HStack {
                Image(systemName: "square.and.arrow.up")
                Text("エクスポート")
                  .font(.headline)
              }
              .foregroundColor(ButtonForeground.color(for: colorScheme))
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
            }
            .glassEffect(.regular.interactive())
          }
        }
        .padding(.horizontal, 20)
        Spacer()
      }

      VStack {
        Spacer()
        HStack {
          Spacer()
          // 削除ボタン
          PreviewFullScreenDeleteButtonView(
            previewIndex: $previewIndex,
            croppedImageSets: croppedImageSets,
            parsedAnswersSets: parsedAnswersSets,
            item: item,
            viewModel: viewModel,
            isPreviewPresented: $isPreviewPresented,
            onDelete: onDelete
          )
        }
        // 削除ボタンがコンテンツに被らないように、少し上にずらす
        .padding(.bottom, 44)
        .padding(.trailing, 20)
      }
    }
    .sheet(isPresented: $isExportPresented) {
      if let it = item, let vm = viewModel {
        ExportView(
          item: it,
          croppedImageSets: croppedImageSets,
          parsedAnswersSets: parsedAnswersSets,
          questionTypes: vm.initialQuestionTypes
        )
      }
    }
  }
}

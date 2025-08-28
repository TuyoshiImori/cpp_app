import SwiftUI

struct BannerView: View {
  let show: Bool
  let title: String

  var body: some View {
    Group {
      if show {
        VStack {
          VStack(alignment: .leading, spacing: 6) {
            Text("新しいアンケートが追加されました")
              .foregroundColor(.white)
              .padding(.horizontal)
            Text("\(title)")
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
  }
}

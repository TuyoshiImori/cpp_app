import SwiftUI
import UIKit

struct DetailImageView: View {
  let image: UIImage?

  var body: some View {
    if let image {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: 300)
    } else {
      Text("Select an item")
    }
  }
}

import SwiftUI

struct BrandHeader: View {
  var body: some View {
    VStack(spacing: 6) {
      Image("AppLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 190, height: 190)
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
      Text("Available Shows").font(.title2).fontWeight(.semibold).offset(y: -58)
    }
    .padding(.top, 40)
    .offset(y: -100)
  }
}



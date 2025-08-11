import SwiftUI

struct StageTabBarItem: Identifiable { let id = UUID(); let title: String; let system: String }

struct StageTabBar: View {
  @Binding var selected: Int // 0 Tickets, 1 Home, 2 Account
  @Namespace private var ns
  private let items = [
    StageTabBarItem(title: "Tickets", system: "ticket.fill"),
    StageTabBarItem(title: "Home", system: "house.fill"),
    StageTabBarItem(title: "Account", system: "person.crop.circle")
  ]
  var body: some View {
    ZStack {
      // Glassy blurred bar with subtle fade
      VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
        .overlay(
          LinearGradient(colors: [Color.black.opacity(0.28), Color.black.opacity(0.12), Color.clear], startPoint: .top, endPoint: .bottom)
        )
        .overlay(Rectangle().fill(StageKit.hairline).frame(height: 1), alignment: .top)
        .frame(height: 94)
        .ignoresSafeArea(edges: .bottom)
      HStack(spacing: 24) {
        ForEach(0..<items.count, id: \.self) { i in
          tab(i)
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 12)
    }
  }
  private func tab(_ i: Int) -> some View {
    let item = items[i]
    let active = selected == i
    let size: CGFloat = (i == 1 ? 56 : 44)
    return Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = i } }) {
      VStack(spacing: 4) {
        ZStack {
          // Soft radial glow under selected tab
          if active {
            RadialGradient(colors: [StageKit.brandEnd.opacity(0.35), .clear], center: .center, startRadius: 2, endRadius: 34)
              .frame(width: size + 24, height: size + 24)
              .offset(y: 10)
          }
          if active {
            Circle()
              .fill(StageKit.brandGradient)
              .matchedGeometryEffect(id: "sel", in: ns)
              .frame(width: size, height: size)
              .shadow(color: StageKit.brandEnd.opacity(0.4), radius: 12, x: 0, y: 6)
          }
          Image(systemName: item.system).foregroundColor(.white)
        }
        Text(item.title).font(.caption2).foregroundColor(active ? .white : .white.opacity(0.7))
      }
      .frame(maxWidth: .infinity)
    }
  }
}

// Blur helper
struct VisualEffectBlur: UIViewRepresentable {
  var blurStyle: UIBlurEffect.Style
  func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: blurStyle)) }
  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}



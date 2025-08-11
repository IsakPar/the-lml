import SwiftUI

enum StageKit {
  // Brand colors
  static let brandStart = Color(red: 0.42, green: 0.36, blue: 0.91) // #6C5CE7
  static let brandEnd   = Color(red: 0.00, green: 0.83, blue: 1.00) // #00D4FF

  // Surfaces
  static let bgDeep   = Color(red: 0.05, green: 0.06, blue: 0.08)   // #0B0F14
  static let bgElev   = Color(red: 0.06, green: 0.07, blue: 0.10)   // #0E131A
  static let hairline = Color.white.opacity(0.08)

  // Status
  static let success = Color(red: 0.13, green: 0.77, blue: 0.37)     // #22C55E
  static let warning = Color(red: 0.96, green: 0.62, blue: 0.04)     // #F59E0B
  static let danger  = Color(red: 0.94, green: 0.27, blue: 0.27)     // #EF4444

  static var brandGradient: LinearGradient {
    LinearGradient(colors: [brandStart, brandEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  static var bgGradient: LinearGradient {
    LinearGradient(colors: [bgDeep, bgElev], startPoint: .top, endPoint: .bottom)
  }
}

struct CardStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(StageKit.bgElev)
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(StageKit.hairline, lineWidth: 1))
      .cornerRadius(16)
      .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
  }
}

extension View {
  func stageCard() -> some View { self.modifier(CardStyle()) }
}



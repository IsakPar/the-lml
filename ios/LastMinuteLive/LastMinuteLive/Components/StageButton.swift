import SwiftUI

struct StagePrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(StageKit.brandGradient)
      .cornerRadius(14)
      .shadow(color: StageKit.brandEnd.opacity(configuration.isPressed ? 0.2 : 0.35), radius: 16, x: 0, y: 8)
      .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
  }
}

struct StageBorderedButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline)
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(.ultraThinMaterial)
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(StageKit.hairline, lineWidth: 1))
      .cornerRadius(12)
      .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
  }
}

extension ButtonStyle where Self == StagePrimaryButtonStyle { static var stagePrimary: StagePrimaryButtonStyle { .init() } }
extension ButtonStyle where Self == StageBorderedButtonStyle { static var stageBordered: StageBorderedButtonStyle { .init() } }



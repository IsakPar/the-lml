import SwiftUI

struct SlimTitleBar: View {
  let title: String
  let subtitle: String?
  let onBack: (() -> Void)?
  
  var body: some View {
    HStack(spacing: 12) {
      // Back button
      if let onBack = onBack {
        Button(action: onBack) {
          Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(StageKit.bgElev.opacity(0.9))
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(StageKit.hairline, lineWidth: 1)
            )
            .cornerRadius(8)
        }
      }
      
      // Title section
      VStack(spacing: 4) {
        Text(title)
          .font(.headline.weight(.semibold))
          .foregroundColor(.white)
        
        if let subtitle = subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
        }
      }
      .frame(maxWidth: .infinity)
      
      Spacer(minLength: 32) // Balance the back button
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
  }
}

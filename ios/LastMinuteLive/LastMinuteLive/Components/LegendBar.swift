import SwiftUI

struct LegendBar: View {
  let tiers: [String: Int] // code -> amountMinor
  
  var body: some View {
    VStack(spacing: 8) {
      Text("Pricing")
        .font(.caption.weight(.medium))
        .foregroundColor(.white.opacity(0.7))
      
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(tiers.keys).sorted(), id: \.self) { code in
            HStack(spacing: 6) {
              Circle()
                .fill(fillColorForTier(code))
                .frame(width: 10, height: 10)
                .overlay(
                  Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
              
              VStack(alignment: .leading, spacing: 2) {
                Text(tierDisplayName(code))
                  .font(.caption2.weight(.medium))
                  .foregroundColor(.white.opacity(0.85))
                  .lineLimit(1)
                
                Text(formatGBP(tiers[code] ?? 0))
                  .font(.caption2.weight(.semibold))
                  .foregroundColor(.white)
              }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
              ZStack {
                StageKit.bgElev.opacity(0.9)
                fillColorForTier(code).opacity(0.08)
              }
            )
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(fillColorForTier(code).opacity(0.25), lineWidth: 0.5)
            )
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
          }
        }
        .padding(.horizontal, 16)
      }
    }
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.black.opacity(0.2))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(StageKit.hairline, lineWidth: 1)
        )
    )
    .padding(.horizontal, 12)
  }
}

private func fillColorForTier(_ tierCode: String) -> Color {
  switch tierCode {
  case "premium": return Color(.sRGB, red: 0.7, green: 0.5, blue: 0.9, opacity: 1.0)
  case "standard": return Color(.sRGB, red: 0.4, green: 0.6, blue: 0.9, opacity: 1.0)
  case "elevated_premium": return Color(.sRGB, red: 0.2, green: 0.7, blue: 0.6, opacity: 1.0)
  case "elevated_standard": return Color(.sRGB, red: 0.9, green: 0.7, blue: 0.3, opacity: 1.0)
  case "budget": return Color(.sRGB, red: 0.8, green: 0.4, blue: 0.4, opacity: 1.0)
  case "restricted": return Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1.0)
  default: return Color(.sRGB, red: 0.6, green: 0.6, blue: 0.6, opacity: 1.0)
  }
}

private func tierDisplayName(_ code: String) -> String {
  switch code {
  case "premium": return "Premium"
  case "elevated_premium": return "Elev. Premium"
  case "standard": return "Standard"
  case "elevated_standard": return "Elev. Standard"
  case "budget": return "Budget"
  case "restricted": return "Restricted"
  default: return code.capitalized
  }
}

private func formatGBP(_ minor: Int) -> String { "£" + String(format: "%.0f", Double(minor)/100.0) }

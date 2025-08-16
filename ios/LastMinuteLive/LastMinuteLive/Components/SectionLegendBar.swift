import SwiftUI

struct SectionInfo {
  let sectionId: String
  let color: String
  let priceTier: String
  let seatCount: Int
}

struct SectionLegendBar: View {
  let seats: [SeatNode]
  let priceTiers: [PriceTier]
  
  var uniqueSections: [SectionInfo] {
    // Group seats by section name and extract unique section info  
    let grouped = Dictionary(grouping: seats) { seat in
      // Use section name from the seat data, with sectionId as fallback
      return seat.sectionId.isEmpty ? "Unknown" : seat.sectionId
    }
    
    return grouped.compactMap { (sectionName, sectionSeats) in
      // Get the first seat to extract section info
      guard let firstSeat = sectionSeats.first,
            let colorHex = firstSeat.colorHex,
            !colorHex.isEmpty else {
        return nil
      }
      
      return SectionInfo(
        sectionId: sectionName,
        color: colorHex,
        priceTier: firstSeat.priceLevelId ?? "standard",
        seatCount: sectionSeats.count
      )
    }.sorted { $0.sectionId < $1.sectionId } // Sort for consistent display
  }
  
  var body: some View {
    VStack(spacing: 8) {
      Text("Sections")
        .font(.caption.weight(.medium))
        .foregroundColor(.white.opacity(0.7))
      
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(uniqueSections, id: \.sectionId) { section in
            HStack(spacing: 6) {
              Circle()
                .fill(Color(hex: section.color))
                .frame(width: 12, height: 12)
                .overlay(
                  Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
              
              VStack(alignment: .leading, spacing: 1) {
                Text(sectionDisplayName(section.sectionId))
                  .font(.caption2.weight(.medium))
                  .foregroundColor(.white.opacity(0.9))
                  .lineLimit(1)
                
                HStack(spacing: 2) {
                  Text("\(section.seatCount) seats")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                  
                  Text("•")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                  
                  Text(formatPrice(for: section.priceTier))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
                }
              }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
              ZStack {
                StageKit.bgElev.opacity(0.9)
                Color(hex: section.color).opacity(0.12)
              }
            )
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: section.color).opacity(0.3), lineWidth: 0.5)
            )
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
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
  
  // ✅ NEW: Helper function to get price for a section's tier
  private func formatPrice(for tierCode: String) -> String {
    guard let priceTier = priceTiers.first(where: { $0.code == tierCode }) else {
      return "£--"
    }
    return "£" + String(format: "%.0f", Double(priceTier.amountMinor) / 100.0)
  }
}

private func sectionDisplayName(_ sectionId: String) -> String {
  // Convert section names to shorter display names
  switch sectionId {
  case "Central Front": return "Central Front"
  case "Upper Left Box": return "Upper L"
  case "Upper Right Box": return "Upper R"
  case "Lower Central": return "Lower Central"
  case "Lower Left Box": return "Lower L"
  case "Lower Right Box": return "Lower R"  
  case "Bottom Left Section": return "Bottom L"
  case "Bottom Right Section": return "Bottom R"
  default:
    // Fallback: return as is or clean up
    return sectionId.count > 15 ? 
      String(sectionId.prefix(12)) + "..." : 
      sectionId
  }
}

// Color extension for hex parsing
private extension Color {
  init(hex: String) {
    let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased()
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    let r, g, b: Double
    if s.count == 6 {
      r = Double((v >> 16) & 0xff) / 255.0
      g = Double((v >> 8) & 0xff) / 255.0
      b = Double(v & 0xff) / 255.0
    } else {
      r = 0.6; g = 0.6; b = 0.6
    }
    self = Color(red: r, green: g, blue: b)
  }
}

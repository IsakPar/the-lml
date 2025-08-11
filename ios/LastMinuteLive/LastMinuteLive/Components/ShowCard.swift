import SwiftUI

struct ShowCard: View {
  let title: String
  let venue: String
  let next: String?
  let imageURL: URL?
  let priceFromMinor: Int?
  let onTap: () -> Void
  
  private var priceText: String {
    if let p = priceFromMinor { return "From £" + String(format: "%.0f", Double(p)/100.0) }
    return "From £—"
  }
  
  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(StageKit.hairline, lineWidth: 1))
          if let url = imageURL {
            AsyncImage(url: url) { phase in
              switch phase {
              case .empty:
                ProgressView().tint(.white.opacity(0.6))
              case .success(let img):
                img.resizable().scaledToFill()
              case .failure:
                Image(systemName: "photo").foregroundColor(.white.opacity(0.6))
              @unknown default:
                EmptyView()
              }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
          } else {
            Image(systemName: "photo").foregroundColor(.white.opacity(0.6))
          }
        }
        .frame(width: 90, height: 120)
        
        VStack(alignment: .leading, spacing: 6) {
          Text(title).font(.headline)
          Text(venue).font(.subheadline).foregroundColor(.secondary)
          if let n = next { Text(n).font(.caption).foregroundColor(.secondary) }
          Spacer()
          HStack {
            Text(priceText).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
              .background(.ultraThinMaterial).cornerRadius(10)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5))
          }
        }
      }
      .padding(12)
      .contentShape(Rectangle())
      .stageCard()
    }
    .buttonStyle(.plain)
  }
}

struct ShowCardSkeleton: View {
  var body: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)).frame(width: 90, height: 120)
      VStack(alignment: .leading, spacing: 8) {
        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)).frame(width: 160, height: 16)
        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)).frame(width: 120, height: 14)
        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)).frame(width: 100, height: 12)
        Spacer()
        RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)).frame(width: 70, height: 20)
      }
    }
    .padding(12)
    .stageCard()
    .redacted(reason: .placeholder)
  }
}



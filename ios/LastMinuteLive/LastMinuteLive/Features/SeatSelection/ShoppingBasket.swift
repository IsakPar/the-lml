import SwiftUI

struct ShoppingBasket: View {
  // MARK: - Properties
  let selectedSeats: [SeatNode]
  let pricePerSeat: Int // in minor units (pence)
  let onCheckout: (String) -> Void // Now passes email to checkout
  let onRemoveSeat: (String) -> Void
  let userEmail: String? // Pre-fill email for logged-in users
  let isUserAuthenticated: Bool // Whether user is logged in (affects validation)
  
  // MARK: - State Management  
  @State private var isVisible = false
  @State private var email: String = ""
  
  // MARK: - Computed Properties
  private var totalPriceMinor: Int {
    selectedSeats.count * pricePerSeat
  }
  
  private var totalPriceText: String {
    "£" + String(format: "%.2f", Double(totalPriceMinor) / 100.0)
  }
  
  private var seatSummaryText: String {
    if selectedSeats.count == 1 {
      return "1 ticket selected"
    } else {
      return "\(selectedSeats.count) tickets selected"
    }
  }
  
  private var isCheckoutEnabled: Bool {
    !selectedSeats.isEmpty && EmailValidator.isValidForCheckout(email)
  }
  
  var body: some View {
    VStack(spacing: 0) {
      if selectedSeats.isEmpty {
        // Empty state - always visible
        VStack(spacing: 12) {
          HStack(spacing: 8) {
            Image(systemName: "hand.tap")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.white.opacity(0.6))
            Text("Select seats to continue")
              .font(.subheadline)
              .foregroundColor(.white.opacity(0.8))
          }
          
          Button(action: {}) {
            HStack(spacing: 8) {
              Image(systemName: "creditcard.fill")
                .font(.system(size: 16, weight: .medium))
              Text("Proceed to Checkout")
                .font(.headline)
                .fontWeight(.semibold)
            }
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(14)
          }
          .disabled(true)
        }
        .padding(16)
        .background(
          ZStack {
            StageKit.bgElev.opacity(0.8)
            Color.white.opacity(0.03)
          }
        )
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(StageKit.hairline.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(20)
        .padding(.horizontal, 16)
      } else {
        // Populated state - with selected seats
        VStack(spacing: 14) {
          // Selected seats chips
          if !selectedSeats.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(selectedSeats, id: \.id) { seat in
                  SeatChip(
                    seat: seat,
                    onRemove: { onRemoveSeat(seat.id) }
                  )
                }
              }
              .padding(.horizontal, 16)
            }
          }
          
          // Email input field for receipt
          EmailInputField(
            email: $email,
            placeholder: isUserAuthenticated ? "Receipt email (optional)" : "Email for receipt",
            prefillEmail: userEmail,
            isRequired: !isUserAuthenticated
          )
          .padding(.horizontal, 16)
          
          // Total and checkout
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(seatSummaryText)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
              Text("Total: \(totalPriceText)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            }
            
            Spacer()
            
            // Basket icon with subtle glow
            ZStack {
              Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 40, height: 40)
              Image(systemName: "basket.fill")
                .foregroundColor(StageKit.brandEnd)
                .font(.system(size: 16, weight: .medium))
            }
          }
          .padding(.horizontal, 16)
          
          // Proceed to Checkout button
          Button(action: {
            let cleanEmail = EmailValidator.clean(email)
            onCheckout(cleanEmail)
          }) {
            HStack(spacing: 8) {
              Image(systemName: "creditcard.fill")
                .font(.system(size: 16, weight: .medium))
              Text("Proceed to Checkout")
                .font(.headline)
                .fontWeight(.semibold)
            }
            .foregroundColor(isCheckoutEnabled ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
              isCheckoutEnabled ? 
              AnyView(StageKit.brandGradient) : 
              AnyView(Color.gray.opacity(0.3))
            )
            .cornerRadius(16)
            .shadow(color: isCheckoutEnabled ? StageKit.brandEnd.opacity(0.4) : Color.clear, radius: 16, x: 0, y: 8)
          }
          .disabled(!isCheckoutEnabled)
          .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(
          ZStack {
            StageKit.bgElev.opacity(0.95)
            Color.white.opacity(0.05)
          }
        )
        .overlay(
          RoundedRectangle(cornerRadius: 24)
            .stroke(StageKit.hairline, lineWidth: 1)
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: -8)
        .padding(.horizontal, 16)
      }
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedSeats.isEmpty)
    .onAppear {
      isVisible = true
    }
  }
}

struct SeatChip: View {
  let seat: SeatNode
  let onRemove: () -> Void
  
  private var seatLabel: String {
    // Use proper row and number if available
    if let row = seat.row, let number = seat.number, !row.isEmpty, !number.isEmpty {
      return "Row \(row), Seat \(number)"
    }
    
    // Fallback to seat ID if row/number not available
    let seatId = seat.id
    
    // Try to extract meaningful info from seat ID or use section
    if !seat.sectionId.isEmpty {
      // If seat ID has more info than just section, use it
      if seatId.count > seat.sectionId.count + 1 {
        return seatId.replacingOccurrences(of: "_", with: " ")
      } else {
        return seat.sectionId
      }
    } else {
      return seatId.replacingOccurrences(of: "_", with: " ")
    }
  }
  
  private var tierColor: Color {
    guard let priceTier = seat.priceLevelId else { return Color.gray }
    switch priceTier {
    case "premium": return Color(.sRGB, red: 0.7, green: 0.5, blue: 0.9, opacity: 1.0)
    case "standard": return Color(.sRGB, red: 0.4, green: 0.6, blue: 0.9, opacity: 1.0)
    case "elevated_premium": return Color(.sRGB, red: 0.2, green: 0.7, blue: 0.6, opacity: 1.0)
    case "elevated_standard": return Color(.sRGB, red: 0.9, green: 0.7, blue: 0.3, opacity: 1.0)
    case "budget": return Color(.sRGB, red: 0.8, green: 0.4, blue: 0.4, opacity: 1.0)
    case "restricted": return Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1.0)
    default: return Color(.sRGB, red: 0.6, green: 0.6, blue: 0.6, opacity: 1.0)
    }
  }
  
  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(tierColor)
        .frame(width: 8, height: 8)
      
      Text(seatLabel)
        .font(.caption.weight(.medium))
        .foregroundColor(.white)
      
      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.white.opacity(0.8))
          .frame(width: 16, height: 16)
          .background(Color.black.opacity(0.3))
          .clipShape(Circle())
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      ZStack {
        StageKit.bgElev.opacity(0.9)
        tierColor.opacity(0.15)
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(tierColor.opacity(0.4), lineWidth: 1)
    )
    .cornerRadius(12)
  }
}
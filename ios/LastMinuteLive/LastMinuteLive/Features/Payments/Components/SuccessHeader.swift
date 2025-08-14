import SwiftUI

struct SuccessHeader: View {
    let eventName: String
    let seatCount: Int
    let eventDate: String
    @State private var animateCheckmark = false
    @State private var animateTitle = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Animated success checkmark
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.8),
                                Color.green
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.6)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateCheckmark)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.3)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateCheckmark)
            }
            .padding(.top, 20)
            
            // Success message
            VStack(spacing: 8) {
                Text("🎫 Your Tickets Are Ready!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .opacity(animateTitle ? 1.0 : 0.0)
                    .offset(y: animateTitle ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: animateTitle)
                
                Text("\(eventName) • \(seatCount) \(seatCount == 1 ? "Seat" : "Seats") • \(eventDate)")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(animateTitle ? 1.0 : 0.0)
                    .offset(y: animateTitle ? 0 : 15)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: animateTitle)
            }
            
            // Celebration particles (optional decorative element)
            HStack(spacing: 20) {
                ForEach(["🎉", "✨", "🎊", "✨", "🎉"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.title3)
                        .opacity(animateTitle ? 0.8 : 0.0)
                        .scaleEffect(animateTitle ? 1.0 : 0.5)
                        .animation(.easeOut(duration: 0.8).delay(Double.random(in: 0.8...1.2)), value: animateTitle)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .onAppear {
            // Trigger animations
            withAnimation {
                animateCheckmark = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    animateTitle = true
                }
            }
        }
    }
}

// MARK: - Compact Success Header (for smaller screens)
struct CompactSuccessHeader: View {
    let eventName: String
    let seatCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Small checkmark
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Tickets Ready!")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(eventName) • \(seatCount) \(seatCount == 1 ? "Seat" : "Seats")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview
struct SuccessHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            SuccessHeader(
                eventName: "Hamilton",
                seatCount: 2,
                eventDate: "Sept 15, 2025"
            )
            
            CompactSuccessHeader(
                eventName: "The Lion King",
                seatCount: 4
            )
        }
        .background(Color(.systemGray6))
        .previewLayout(.sizeThatFits)
    }
}

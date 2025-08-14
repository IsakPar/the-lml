import SwiftUI

struct CleanSuccessHeader: View {
    let eventName: String
    let seatCount: Int
    let eventDate: String
    @State private var animateCheckmark = false
    @State private var animateContent = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Clean success checkmark
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                StageKit.success.opacity(0.9),
                                StageKit.success
                            ]),
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 64, height: 64)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.3)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateCheckmark)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.2)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateCheckmark)
            }
            .padding(.top, 32)
            
            // Success message
            VStack(spacing: 12) {
                Text("Payment Successful")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(animateContent ? 1.0 : 0.0)
                    .offset(y: animateContent ? 0 : 15)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: animateContent)
                
                Text("Your tickets are ready")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(animateContent ? 1.0 : 0.0)
                    .offset(y: animateContent ? 0 : 10)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: animateContent)
                
                // Event summary
                Text("\(eventName) • \(seatCount) \(seatCount == 1 ? "seat" : "seats") • \(eventDate)")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .opacity(animateContent ? 1.0 : 0.0)
                    .offset(y: animateContent ? 0 : 8)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: animateContent)
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation {
                animateCheckmark = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    animateContent = true
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
        HStack(spacing: 16) {
            // Small success indicator
            ZStack {
                Circle()
                    .fill(StageKit.success)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Payment Successful")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("\(eventName) • \(seatCount) \(seatCount == 1 ? "seat" : "seats")")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview
struct CleanSuccessHeader_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            VStack(spacing: 40) {
                CleanSuccessHeader(
                    eventName: "Hamilton",
                    seatCount: 2,
                    eventDate: "Sept 15"
                )
                
                CompactSuccessHeader(
                    eventName: "The Lion King",
                    seatCount: 4
                )
            }
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}

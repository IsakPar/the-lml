import SwiftUI

struct SimpleNavigation: View {
    let onSeeMyTickets: () -> Void
    let onBackToShows: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary action - See My Tickets
            Button(action: onSeeMyTickets) {
                HStack(spacing: 8) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("See My Tickets")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    StageKit.brandStart,
                                    StageKit.brandEnd
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundColor(.white)
                .shadow(color: StageKit.brandEnd.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // Secondary action - Back to Shows
            Button(action: onBackToShows) {
                Text("Back to Shows")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Compact Navigation (for smaller spaces)
struct CompactNavigation: View {
    let onSeeMyTickets: () -> Void
    let onBackToShows: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Back to Shows - Compact
            Button(action: onBackToShows) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Shows")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .foregroundColor(.white.opacity(0.9))
            }
            
            // See My Tickets - Primary
            Button(action: onSeeMyTickets) {
                HStack(spacing: 6) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("My Tickets")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(StageKit.brandGradient)
                )
                .foregroundColor(.white)
                .shadow(color: StageKit.brandEnd.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Navigation Button Style (if needed separately)
struct NavigationButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct SimpleNavigation_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                SimpleNavigation(
                    onSeeMyTickets: { print("See My Tickets tapped") },
                    onBackToShows: { print("Back to Shows tapped") }
                )
                
                CompactNavigation(
                    onSeeMyTickets: { print("My Tickets tapped") },
                    onBackToShows: { print("Shows tapped") }
                )
            }
        }
    }
}

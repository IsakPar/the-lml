import SwiftUI

/// Clean, modular seatmap canvas component 
/// Renders seats with proper DDD separation of concerns
public struct SeatmapCanvas: View {
    let seats: [SeatNode]
    let transformResult: SeatmapTransformResult?
    let canvasSize: CGSize
    let selectedSeats: Set<String>
    let seatAvailability: [String: SeatAvailabilityStatus]
    let onSeatTap: (String) -> Void
    
    init(
        seats: [SeatNode],
        transformResult: SeatmapTransformResult?,
        canvasSize: CGSize,
        selectedSeats: Set<String>,
        seatAvailability: [String: SeatAvailabilityStatus],
        onSeatTap: @escaping (String) -> Void
    ) {
        self.seats = seats
        self.transformResult = transformResult
        self.canvasSize = canvasSize
        self.selectedSeats = selectedSeats
        self.seatAvailability = seatAvailability
        self.onSeatTap = onSeatTap
    }
    
    public var body: some View {
        ScrollView([.vertical, .horizontal]) {
            ZStack(alignment: .topLeading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                
                // Seats Layer
                SeatsLayer(
                    seats: seats,
                    transformResult: transformResult,
                    selectedSeats: selectedSeats,
                    seatAvailability: seatAvailability,
                    onSeatTap: onSeatTap
                )
                
                // Stage Visualization
                StageView(canvasSize: canvasSize)
                
                // Empty State
                if seats.isEmpty {
                    Text("No seats parsed")
                        .foregroundColor(.yellow)
                        .position(x: 160, y: 80)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        }
    }
}

// MARK: - Internal Components

private struct SeatsLayer: View {
    let seats: [SeatNode]
    let transformResult: SeatmapTransformResult?
    let selectedSeats: Set<String>
    let seatAvailability: [String: SeatAvailabilityStatus]
    let onSeatTap: (String) -> Void
    
    var body: some View {
        let scale = transformResult?.scale ?? 1.0
        let flippedY = transformResult?.flippedY ?? false
        let dx = transformResult?.dx ?? 0
        let dy = transformResult?.dy ?? 0
        let rPx = transformResult?.seatRadiusPx ?? 8
        let minX = transformResult?.minX ?? 0
        let worldH = transformResult?.worldH ?? 0
        
        ForEach(Array(seats.enumerated()), id: \.element.id) { index, seat in
            SeatView(
                seat: seat,
                scale: scale,
                flippedY: flippedY,
                dx: dx,
                dy: dy,
                worldH: worldH,
                radiusPx: rPx,
                isSelected: selectedSeats.contains(seat.id),
                availability: seatAvailability[seat.id] ?? .blocked,
                onTap: { onSeatTap(seat.id) }
            )
        }
    }
}

private struct SeatView: View {
    let seat: SeatNode
    let scale: CGFloat
    let flippedY: Bool
    let dx: CGFloat
    let dy: CGFloat
    let worldH: CGFloat
    let radiusPx: CGFloat
    let isSelected: Bool
    let availability: SeatAvailabilityStatus
    let onTap: () -> Void
    
    var body: some View {
        let isLargeBlock = seat.w > 0.05 || seat.h > 0.05
        let seatWidth: CGFloat = isLargeBlock ? seat.w * scale : radiusPx * 2.6
        let seatHeight: CGFloat = isLargeBlock ? seat.h * scale : radiusPx * 2.0
        let width: CGFloat = seatWidth
        let height: CGFloat = seatHeight
        let x = seat.x * scale + dx
        let y = flippedY ? (worldH - seat.y) * scale + dy : seat.y * scale + dy
        let cx = x + width / 2.0
        let cy = y + height / 2.0
        
        Button(action: {
            // Only allow selection of available seats
            if availability.canBeSelected() {
                onTap()
            }
        }) {
            SeatShape(
                width: width,
                height: height,
                isLargeBlock: isLargeBlock,
                isSelected: isSelected,
                availability: availability
            )
        }
        .position(x: cx, y: cy)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

private struct SeatShape: View {
    let width: CGFloat
    let height: CGFloat
    let isLargeBlock: Bool
    let isSelected: Bool
    let availability: SeatAvailabilityStatus
    
    var body: some View {
        Group {
            if isLargeBlock {
                RoundedRectangle(cornerRadius: 8)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.2), lineWidth: 2)
                    )
            } else {
                // Realistic theater seat shape
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.8)
                    )
                    .overlay(
                        // Subtle seat texture
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear,
                                        Color.black.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .frame(width: width, height: height)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .shadow(
            color: isSelected ? StageKit.brandEnd.opacity(0.4) : Color.clear,
            radius: isSelected ? 8 : 0,
            x: 0, y: 2
        )
    }
    
    private var fillColor: Color {
        switch availability {
        case .available:
            if isSelected {
                return StageKit.brandEnd
            } else {
                return StageKit.success.opacity(0.7)
            }
        case .held:
            return Color.yellow.opacity(0.6)
        case .sold:
            return Color.red.opacity(0.4)
        case .blocked:
            return Color.gray.opacity(0.3)
        }
    }
}

private struct StageView: View {
    let canvasSize: CGSize
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.8), Color.gray.opacity(0.6)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .stroke(Color.yellow.opacity(0.8), lineWidth: 2)
                .frame(width: canvasSize.width * 0.6, height: 32)
            Text("STAGE")
                .font(.caption.bold())
                .foregroundColor(Color.yellow.opacity(0.9))
                .offset(y: -20)
        }
        .position(x: canvasSize.width / 2, y: 24)
    }
}
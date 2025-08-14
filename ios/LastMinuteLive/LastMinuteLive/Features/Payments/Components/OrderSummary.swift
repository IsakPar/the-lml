import SwiftUI

struct OrderDetailsView: View {
    let orderData: OrderSummaryData
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Email confirmation (always visible)
            EmailConfirmationCard(email: orderData.customerEmail)
            
            // Expandable order details
            VStack(spacing: 12) {
                // Header with expand/collapse
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "receipt")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Text("Order Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.3), value: isExpanded)
                    }
                    .padding(.horizontal, 20)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Expandable details
                if isExpanded {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 8) {
                            OrderDetailRow(
                                label: "Order ID",
                                value: orderData.fullOrderId,
                                copyable: true
                            )
                            
                            OrderDetailRow(
                                label: "Total Paid",
                                value: formatGBP(orderData.totalAmount),
                                highlighted: true
                            )
                            
                            OrderDetailRow(
                                label: "Tickets",
                                value: "\(orderData.seatCount) \(orderData.seatCount == 1 ? "ticket" : "tickets")"
                            )
                            
                            if orderData.seatNumbers.count <= 5 {
                                OrderDetailRow(
                                    label: "Seat Numbers",
                                    value: orderData.seatNumbers.joined(separator: ", ")
                                )
                            }
                            
                            OrderDetailRow(
                                label: "Payment Method",
                                value: orderData.paymentMethod
                            )
                            
                            OrderDetailRow(
                                label: "Purchase Date",
                                value: orderData.purchaseDate
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 20)
        }
    }
    
    private func formatGBP(_ minor: Int) -> String {
        "£" + String(format: "%.2f", Double(minor) / 100.0)
    }
}

// MARK: - Email Confirmation Card
struct EmailConfirmationCard: View {
    let email: String?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Receipt Emailed")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let email = email {
                    Text("Sent to: \(email)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Check your email for confirmation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Order Detail Row
struct OrderDetailRow: View {
    let label: String
    let value: String
    let copyable: Bool
    let highlighted: Bool
    
    init(label: String, value: String, copyable: Bool = false, highlighted: Bool = false) {
        self.label = label
        self.value = value
        self.copyable = copyable
        self.highlighted = highlighted
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(minWidth: 100, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.body)
                    .fontWeight(highlighted ? .semibold : .medium)
                    .foregroundColor(highlighted ? .green : .primary)
                    .multilineTextAlignment(.trailing)
                
                if copyable {
                    Button(action: {
                        UIPasteboard.general.string = value
                        // TODO: Show toast notification
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// MARK: - Order Summary Data Model
struct OrderSummaryData {
    let fullOrderId: String
    let totalAmount: Int
    let seatCount: Int
    let seatNumbers: [String]
    let paymentMethod: String
    let purchaseDate: String
    let customerEmail: String?
}

// MARK: - Preview
struct OrderDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                OrderDetailsView(
                    orderData: OrderSummaryData(
                        fullOrderId: "b55c7a7f-c552-4ce0-aba0-e4f4a7414e65",
                        totalAmount: 7500, // £75.00
                        seatCount: 2,
                        seatNumbers: ["A-12", "A-13"],
                        paymentMethod: "•••• 4242 (Visa)",
                        purchaseDate: "Sep 15, 2025 at 2:45 PM",
                        customerEmail: "user@example.com"
                    )
                )
                
                OrderDetailsView(
                    orderData: OrderSummaryData(
                        fullOrderId: "a44b66c2-d441-3bd9-8fe2-c8e5a6d7b9f1",
                        totalAmount: 15000, // £150.00
                        seatCount: 4,
                        seatNumbers: ["C-5", "C-6", "C-7", "C-8"],
                        paymentMethod: "Apple Pay",
                        purchaseDate: "Dec 20, 2025 at 11:30 AM",
                        customerEmail: nil
                    )
                )
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGray6))
    }
}

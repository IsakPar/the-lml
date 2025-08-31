import SwiftUI
import StripePaymentSheet
import PassKit
import MapKit

/// Clean, modular seatmap screen following DDD principles
/// Acts as a coordinator/presenter with minimal business logic
struct SeatmapScreen: View {
    
    // MARK: - Dependencies
    
    @EnvironmentObject var app: AppState
    let show: Show
    let navigationCoordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Services (Injected)
    
    @StateObject private var seatmapService: SeatmapService
    
    // MARK: - View State (Minimal)
    
    @State private var selectedSeats: Set<String> = []
    @State private var showSuccessScreen = false
    @State private var successData: PaymentSuccessData?
    @State private var seatHoldService: SeatHoldService?
    
    // MARK: - Payment State
    
    @State private var showCheckout = false
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentResult: PaymentSheetResult?
    @State private var isCreatingOrder = false
    @State private var lastOrderResponse: CreateOrderResponse?
    
    // MARK: - Initialization with Dependency Injection
    
    init(show: Show, navigationCoordinator: NavigationCoordinator, apiClient: ApiClient) {
        self.show = show
        self.navigationCoordinator = navigationCoordinator
        
        // Initialize services with proper dependencies
        let seatmapRepo = SeatmapRepository(apiClient: apiClient)
        let priceTierRepo = PriceTierRepository(apiClient: apiClient)
        let seatAvailabilityRepo = SeatAvailabilityRepository(apiClient: apiClient)
        
        self._seatmapService = StateObject(wrappedValue: SeatmapService(
            seatmapRepository: seatmapRepo,
            priceTierRepository: priceTierRepo,
            seatAvailabilityRepository: seatAvailabilityRepo
        ))
    }
    
    // MARK: - View Body
    
    var body: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Section
                HeaderSection(
                    show: show,
                    seatmapModel: seatmapService.model,
                    priceTiers: seatmapService.priceTiers,
                    onDismiss: { dismiss() }
                )
                
                // Main Content
                MainContentSection(
                    seatmapService: seatmapService,
                    selectedSeats: selectedSeats,
                    onSeatTap: handleSeatTap
                )
                
                // Reserve space for shopping basket
                Color.clear.frame(height: selectedSeats.isEmpty ? 100 : 140)
            }
        }
        .overlay(alignment: .bottom) {
            // Shopping Basket
            ShoppingBasketSection(
                selectedSeats: selectedSeats,
                seatmapService: seatmapService,
                userEmail: app.userEmail,
                isUserAuthenticated: app.isAuthenticated,
                onCheckout: handleCheckout,
                onRemoveSeat: handleRemoveSeat
            )
        }
        .navigationBarHidden(true)
        .paymentSheet(isPresented: $showCheckout, 
                      paymentSheet: paymentSheet ?? PaymentSheet(paymentIntentClientSecret: "", configuration: PaymentSheet.Configuration()),
                      onCompletion: handlePaymentResult)
        .sheet(isPresented: $showSuccessScreen) {
            if let successData = successData {
                PaymentSuccessScreen(
                    successData: successData,
                    navigationCoordinator: navigationCoordinator
                )
            }
        }
        .onAppear {
            setupServices()
        }
    }
    
    // MARK: - Business Logic (Minimal - Delegates to Services)
    
    private func setupServices() {
        Task {
            // 🚨 REMOVED: Auto-authentication that was breaking guest UX
            // Guest users should remain guests until they choose to log in
            
            // Create SeatHoldService with current API client (works for both guest and authenticated)
            await MainActor.run {
                seatHoldService = SeatHoldService(apiClient: app.api)
                print("[SeatmapScreen] 🎫 SeatHoldService created")
            }
            
            // Load seatmap data (works for both guest and authenticated users)
            await seatmapService.loadSeatmapData(for: show)
            print("[SeatmapScreen] ✅ Services setup completed - user remains in original auth state")
        }
    }
    
    private func handleSeatTap(seatId: String) {
        Task {
            // Validate with domain rules
            let validationResult = seatmapService.validateSeatSelection(
                seatId: seatId,
                currentSelection: selectedSeats
            )
            
            switch validationResult {
            case .success:
                if selectedSeats.contains(seatId) {
                    // Remove from selection
                    await removeSeat(seatId)
                } else {
                    // Add to selection
                    await addSeat(seatId)
                }
                
            case .failure(let error):
                print("[SeatmapScreen] ❌ Seat selection failed: \(error.userMessage)")
                // TODO: Show user-friendly error message
            }
        }
    }
    
    private func addSeat(_ seatId: String) async {
        guard let seatHoldService = seatHoldService,
              let performanceId = seatmapService.performanceId else { return }
        
        do {
            // ✅ FIXED: Use correct API - holdSeats([String], performanceId)
            try await seatHoldService.holdSeats(
                [seatId], 
                performanceId: performanceId
            )
            
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedSeats.insert(seatId)
                }
            }
            
        } catch {
            print("[SeatmapScreen] ❌ Failed to hold seat: \(error)")
        }
    }
    
    private func removeSeat(_ seatId: String) async {
        guard let seatHoldService = seatHoldService else { return }
        
        // ✅ FIXED: Use correct API - releaseSeats([String])
        seatHoldService.releaseSeats([seatId])
        
        await MainActor.run {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSeats.remove(seatId)
            }
        }
    }
    
    private func handleCheckout(customerEmail: String) {
        guard let performanceId = seatmapService.performanceId else { return }
        
        let pricePerSeat = seatmapService.getDefaultPricePerSeat()
        let orderData = OrderCreationData(
            performanceId: performanceId,
            seatIds: Array(selectedSeats),
            pricePerSeat: pricePerSeat,
            customerEmail: customerEmail
        )
        
        isCreatingOrder = true
        
        Task {
            await createOrderAndPresentPaymentSheet(orderData: orderData)
        }
    }
    
    private func createOrderAndPresentPaymentSheet(orderData: OrderCreationData) async {
        print("[SeatmapScreen] 🚀 Starting checkout process...")
        print("[SeatmapScreen] Selected seats: \(orderData.seatIds)")
        print("[SeatmapScreen] Performance ID: \(orderData.performanceId)")
        print("[SeatmapScreen] Customer email: \(orderData.customerEmail)")
        
        do {
            // Create order request
            let requestBody = CreateOrderRequest(
                performance_id: orderData.performanceId,
                seat_ids: orderData.seatIds,
                currency: orderData.currency,
                total_minor: orderData.totalAmountMinor,
                customer_email: orderData.customerEmail
            )
            
            print("[SeatmapScreen] 💰 Total amount: \(orderData.totalAmountMinor) (\(orderData.formattedTotal()))")
            
            // Create order via API
            let bodyData = try JSONEncoder().encode(requestBody)
            // Attach hold token from SeatHoldService for server-side verification
            var orderHeaders: [String: String] = [
                "Idempotency-Key": "order_\(UUID().uuidString)"
            ]
            if let anyHeld = seatHoldService?.getAllHeldSeats().first?.holdToken {
                orderHeaders["X-Seat-Hold-Token"] = anyHeld
            }
            let (responseData, _) = try await app.api.request(
                path: "/v1/orders",
                method: "POST",
                body: bodyData,
                headers: orderHeaders
            )
            
            let orderResponse = try JSONDecoder().decode(CreateOrderResponse.self, from: responseData)
            print("[SeatmapScreen] ✅ Order \(orderResponse.order_id) created successfully")
            
            // Store order response for success screen
            lastOrderResponse = orderResponse
            
            // Configure Stripe PaymentSheet
            StripeAPI.defaultPublishableKey = Config.stripePublishableKey
            
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "LastMinuteLive"
            configuration.allowsDelayedPaymentMethods = false
            
            // ✅ RESTORED: Add Apple Pay configuration if available
            if PKPaymentAuthorizationViewController.canMakePayments() {
                print("[SeatmapScreen] 🍎 Apple Pay is available, adding to configuration")
                configuration.applePay = .init(
                    merchantId: Config.merchantIdentifier,
                    merchantCountryCode: Config.countryCode
                )
            } else {
                print("[SeatmapScreen] ⚠️ Apple Pay not available on this device")
            }
            
            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: orderResponse.client_secret,
                configuration: configuration
            )
            
            await MainActor.run {
                showCheckout = true
                isCreatingOrder = false
            }
            
        } catch {
            await MainActor.run {
                isCreatingOrder = false
                print("[SeatmapScreen] ❌ Payment setup failed: \(error)")
                // TODO: Show error alert
            }
        }
    }
    
    private func handleRemoveSeat(seatId: String) {
        Task {
            await removeSeat(seatId)
        }
    }
    
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            print("[SeatmapScreen] ✅ Payment completed successfully!")
            
            let selectedSeatNodes = seatmapService.getSelectedSeatNodes(from: selectedSeats)
            let venueCoords = VenueCoordinatesProvider.getCoordinatesTuple(for: show.venue)
            
            // Create success data using lastOrderResponse
            if let orderResponse = lastOrderResponse {
                let successData = PaymentSuccessData(
                    orderId: orderResponse.order_id,
                    totalAmount: orderResponse.total_amount,
                    currency: orderResponse.currency,
                    seatIds: Array(selectedSeats),
                    seatNodes: selectedSeatNodes,
                    performanceName: show.title,
                    performanceDate: formatPerformanceDate(show.nextPerformance ?? ""),
                    venueName: show.venue,
                    venueCoordinates: CLLocationCoordinate2D(
                        latitude: venueCoords.latitude,
                        longitude: venueCoords.longitude
                    ),
                    customerEmail: orderResponse.customer_email, // ✅ FIXED: Extract email from order
                    paymentMethod: "Card",
                    purchaseDate: formatCurrentDateTime()
                )
                
                self.successData = successData
                selectedSeats.removeAll()
                showSuccessScreen = true
            }
            
        case .canceled:
            print("[SeatmapScreen] 💸 Payment was canceled")
            // Keep seats selected for retry
            
        case .failed(let error):
            print("[SeatmapScreen] ❌ Payment failed: \(error)")
            // TODO: Show error alert
        }
        
        showCheckout = false
    }
    
    // MARK: - Helper Functions
    
    private func formatPerformanceDate(_ isoDateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoDateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .full
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return isoDateString
    }
    
    private func formatCurrentDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - UI Section Components

private struct HeaderSection: View {
    let show: Show
    let seatmapModel: SeatmapModel?
    let priceTiers: [PriceTier]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            SlimTitleBar(
                title: show.title,
                subtitle: show.venue,
                onBack: onDismiss
            )
            
            // Legend
            if let model = seatmapModel, !model.seats.isEmpty {
                SectionLegendBar(seats: model.seats, priceTiers: priceTiers)
            } else if !priceTiers.isEmpty {
                let tierDict = Dictionary(uniqueKeysWithValues: priceTiers.map { ($0.code, $0.amountMinor) })
                LegendBar(tiers: tierDict)
            }
        }
    }
}

private struct MainContentSection: View {
    @ObservedObject var seatmapService: SeatmapService
    let selectedSeats: Set<String>
    let onSeatTap: (String) -> Void
    
    var body: some View {
        Group {
            if seatmapService.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if let error = seatmapService.error {
                ErrorView(message: error)
                
            } else if let model = seatmapService.model {
                GeometryReader { geo in
                    let rawCanvas = geo.size
                    let canvas = (rawCanvas.width < 100 || rawCanvas.height < 100) 
                        ? UIScreen.main.bounds.size 
                        : rawCanvas
                    
                    // ✅ RESTORED: Advanced transform options from original (fixes right seat cutoff)
                    let options: SeatmapTransformOptions = {
                        var opts = SeatmapTransformOptions()
                        opts.flipOverride = false
                        opts.paddingPx = 15.0
                        opts.useOptimalScaling = true
                        opts.usePerfectCentering = true
                        opts.centeringOffsetX = -37.5  // Critical: prevents right seats cutoff
                        return opts
                    }()
                    let worldSize = CGSize(width: model.viewportWidth, height: model.viewportHeight)
                    let transformResult = try? computeSeatmapTransform(
                        seats: model.seats, 
                        worldSize: worldSize, 
                        canvasSize: canvas, 
                        options: options
                    )
                    
                    // ✅ FIXED: Use new modular SeatmapCanvas with proper transform
                    SeatmapCanvas(
                        seats: model.seats,
                        transformResult: transformResult,
                        canvasSize: canvas,
                        selectedSeats: selectedSeats,
                        seatAvailability: seatmapService.seatAvailability,
                        onSeatTap: { seatId in
                            onSeatTap(seatId)
                        }
                    )
                }
            }
        }
    }
}

private struct ShoppingBasketSection: View {
    let selectedSeats: Set<String>
    @ObservedObject var seatmapService: SeatmapService
    let userEmail: String?
    let isUserAuthenticated: Bool
    let onCheckout: (String) -> Void
    let onRemoveSeat: (String) -> Void
    
    var body: some View {
        let selectedSeatNodes = seatmapService.getSelectedSeatNodes(from: selectedSeats)
        let pricePerSeat = seatmapService.getDefaultPricePerSeat()
        
        ShoppingBasket(
            selectedSeats: selectedSeatNodes,
            pricePerSeat: pricePerSeat,
            onCheckout: onCheckout,
            onRemoveSeat: onRemoveSeat,
            userEmail: userEmail,
            isUserAuthenticated: isUserAuthenticated
        )
        .padding(.bottom, 0)
    }
}

private struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text(message)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Infrastructure Service

public final class VenueCoordinatesProvider {
    
    private static let venueCoordinates: [String: (latitude: Double, longitude: Double)] = [
        "victoria palace theatre": (51.4942, -0.1358),
        "lyceum theatre": (51.5115, -0.1203),
        "palace theatre": (51.5135, -0.1286),
        "theatre royal drury lane": (51.5127, -0.1206),
        "her majesty's theatre": (51.5103, -0.1324),
        "london palladium": (51.5148, -0.1406),
        "apollo theatre": (51.5108, -0.1302),
        "phoenix theatre": (51.5144, -0.1298)
    ]
    
    private static let defaultCoordinates = (latitude: 51.5074, longitude: -0.1278)
    
    public static func getCoordinatesTuple(for venueName: String) -> (latitude: Double, longitude: Double) {
        let normalizedName = venueName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct lookup
        if let coordinates = venueCoordinates[normalizedName] {
            return coordinates
        }
        
        // Fuzzy matching
        for (venueName, coordinates) in venueCoordinates {
            if normalizedName.contains(venueName) || venueName.contains(normalizedName) {
                return coordinates
            }
        }
        
        return defaultCoordinates
    }
}

// MARK: - Preview

struct SeatmapScreen_Previews: PreviewProvider {
    static var previews: some View {
        SeatmapScreen(
            show: Show(
                id: "test-show",
                title: "Hamilton",
                venue: "Theatre Royal Drury Lane",
                nextPerformance: "2025-09-15T19:30:00Z",
                posterUrl: nil,
                priceFromMinor: 2500,
                performanceId: nil
            ),
            navigationCoordinator: NavigationCoordinator(),
            apiClient: ApiClient(baseURL: URL(string: "http://localhost:3000")!) // ✅ FIXED: Use URL()
        )
        .environmentObject(AppState())
    }
}

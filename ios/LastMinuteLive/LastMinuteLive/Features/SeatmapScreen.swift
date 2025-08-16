import SwiftUI
import Stripe
import StripePaymentSheet
import PassKit
import MapKit

// MARK: - Order Models

struct CreateOrderRequest: Codable {
  let performance_id: String
  let seat_ids: [String]
  let currency: String
  let total_minor: Int
  let customer_email: String
}

struct CreateOrderResponse: Codable {
  let order_id: String
  let client_secret: String
  let total_amount: Int
  let currency: String
}

private struct Tier { 
  let code: String
  let name: String
  let amountMinor: Int
  let color: String?
}

struct SeatmapScreen: View {
  @EnvironmentObject var app: AppState
  let show: Show
  let navigationCoordinator: NavigationCoordinator
  @Environment(\.dismiss) private var dismiss
  @State private var model: SeatmapModel? = nil
  @State private var warnings: [String] = []
  @State private var error: String? = nil
  @State private var loading = true
  @State private var tiers: [Tier] = []
  @State private var selectedSeats: Set<String> = []
  @State private var seatAvailability: [String: String] = [:] // seat_id -> status
  @State private var seatHoldService: SeatHoldService? = nil
  @State private var performanceId: String? = nil
  @State private var showCheckout = false
  @State private var paymentSheet: PaymentSheet?
  @State private var paymentResult: PaymentSheetResult?
  @State private var isCreatingOrder = false
  @State private var showSuccessScreen = false
  @State private var successData: PaymentSuccessData?
  @State private var lastOrderResponse: CreateOrderResponse?
  @State private var selectedSeatNodes: [SeatNode] = []
  
  var body: some View {
    ZStack {
      StageKit.bgGradient.ignoresSafeArea()
      
      VStack(spacing: 0) {
        // Header section
        VStack(spacing: 12) {
          // Title bar with back button
          SlimTitleBar(
            title: show.title,
            subtitle: show.venue,
            onBack: { dismiss() }
          )
          
          // Legend - show unique section colors from seatmap
          if let model = model, !model.seats.isEmpty {
            SectionLegendBar(seats: model.seats)
          } else if !tiers.isEmpty {
            LegendBar(tiers: Dictionary(uniqueKeysWithValues: tiers.map { ($0.code, $0.amountMinor) }))
          }
        }
        .background(Color.clear)
        
        // Main seatmap content
        Group {
          if loading {
            ProgressView().tint(.white)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if let e = error {
            VStack(spacing: 12) {
              Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.orange)
              Text(e)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if let m = model {
            GeometryReader { geo in
              let rawCanvas = geo.size
              let canvas = (rawCanvas.width < 100 || rawCanvas.height < 100) ? UIScreen.main.bounds.size : rawCanvas
              let options: SeatmapTransformOptions = {
                var opts = SeatmapTransformOptions()
                opts.flipOverride = false
                opts.paddingPx = 15.0
                opts.useOptimalScaling = true
                opts.usePerfectCentering = true
                opts.centeringOffsetX = -37.5
                return opts
              }()
              let worldSize = CGSize(width: m.viewportWidth, height: m.viewportHeight)
              let res = try? computeSeatmapTransform(seats: m.seats, worldSize: worldSize, canvasSize: canvas, options: options)
              
              ScrollView([.vertical, .horizontal]) {
                ZStack(alignment: .topLeading) {
                  Rectangle().fill(Color.white.opacity(0.04))
                  
                  SeatsLayerView(
                    seats: m.seats,
                    res: res,
                    canvas: canvas,
                    selectedSeats: selectedSeats,
                    seatAvailability: seatAvailability,
                    seatHoldService: seatHoldService,
                    onSeatTap: { seatId in
                      Task {
                        await handleSeatTap(seatId: seatId)
                      }
                    }
                  )
                  
                  // Stage visualization
                  ZStack {
                    RoundedRectangle(cornerRadius: 8)
                      .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.8), Color.gray.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                      ))
                      .stroke(Color.gold, lineWidth: 2)
                      .frame(width: canvas.width * 0.6, height: 32)
                    Text("STAGE")
                      .font(.caption.bold())
                      .foregroundColor(Color.gold.opacity(0.9))
                      .offset(y: -20)
                  }
                  .position(x: canvas.width / 2, y: 24)
                  
                  if m.seats.isEmpty {
                    Text("No seats parsed")
                      .foregroundColor(.yellow)
                      .position(x: 160, y: 80)
                  }
                }
                .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
              }
            }
          }
        }
        
        // Reserve space for shopping basket - always present
        Color.clear.frame(height: selectedSeats.isEmpty ? 100 : 140)
      }
    }
    .overlay(alignment: .bottom) {
      // Shopping basket - always visible
      let selectedSeatNodes = model?.seats.filter { selectedSeats.contains($0.id) } ?? []
      let pricePerSeat = tiers.first?.amountMinor ?? 8500
      
      ShoppingBasket(
        selectedSeats: selectedSeatNodes,
        pricePerSeat: pricePerSeat,
        onCheckout: { customerEmail in
          print("[ShoppingBasket] 🛒 Checkout button pressed with \(selectedSeats.count) seats, email: \(customerEmail)")
          createOrderAndPresentPaymentSheet(customerEmail: customerEmail)
        },
        onRemoveSeat: { seatId in
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            _ = selectedSeats.remove(seatId)
          }
        },
        userEmail: app.userEmail
      )
      .padding(.bottom, 0)
    }
    .navigationBarHidden(true)
    .paymentSheet(isPresented: $showCheckout, 
                  paymentSheet: paymentSheet ?? PaymentSheet(paymentIntentClientSecret: "", configuration: PaymentSheet.Configuration()),
                  onCompletion: { result in
      paymentResult = result
      handlePaymentResult(result)
    })
    .sheet(isPresented: $showSuccessScreen) {
      if let successData = successData {
        PaymentSuccessScreen(
          successData: successData,
          navigationCoordinator: navigationCoordinator
        )
      }
    }
    .onAppear { 
      seatHoldService = SeatHoldService(apiClient: app.api)
      load() 
    }
  }
  
  private func load() {
    loading = true; error = nil
    Task { @MainActor in
      do {
        // Authenticate for development if not already authenticated
        await app.authenticateForDevelopment()
        print("[Seatmap] Fetching seatmap for show: \(show.id)")
        let (res, _) = try await app.api.request(path: "/v1/shows/" + show.id + "/seatmap", headers: ["X-Org-ID": Config.defaultOrgId])
        let seatmapId: String
        if let o = try JSONSerialization.jsonObject(with: res) as? [String: Any], let s = o["seatmapId"] as? String { 
          seatmapId = s 
        } else { throw NSError(domain: "seatmap", code: 404) }
        
        let (data, _) = try await app.api.request(path: "/v1/seatmaps/" + seatmapId, headers: ["X-Org-ID": Config.defaultOrgId])
        if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
          let raw = (obj["data"] as? [String: Any]) ?? obj
          do {
            let parsed0 = try SeatmapParser.parse(raw: raw)
            print("[Seatmap] fetched seats=\(parsed0.seats.count)")
            self.model = parsed0
            self.warnings = parsed0.warnings
          } catch {
            self.error = "Failed to parse seatmap: \(error.localizedDescription)"
          }
        } else { self.error = "Invalid seatmap JSON" }
        
        // Fetch price tiers
        let (ptData, _) = try await app.api.request(path: "/v1/shows/" + show.id + "/price-tiers", headers: ["X-Org-ID": Config.defaultOrgId])
        if let ptObj = try JSONSerialization.jsonObject(with: ptData) as? [String: Any],
           let ptArray = ptObj["data"] as? [[String: Any]] {
          self.tiers = ptArray.compactMap { dict in
            guard let code = dict["code"] as? String,
                  let name = dict["name"] as? String,
                  let amountMinor = dict["amount_minor"] as? Int else { return nil }
            return Tier(code: code, name: name, amountMinor: amountMinor, color: dict["color"] as? String)
          }
        }
        
        // Fetch real seat availability from Postgres
        let (availData, _) = try await app.api.request(path: "/v1/shows/" + show.id + "/seat-availability", headers: ["X-Org-ID": Config.defaultOrgId])
        if let availObj = try JSONSerialization.jsonObject(with: availData) as? [String: Any] {
          if let availMap = availObj["data"] as? [String: String] {
            self.seatAvailability = availMap
            print("[Seatmap] Loaded seat availability: \(availMap.count) seats")
          }
          if let perfId = availObj["performance_id"] as? String {
            self.performanceId = perfId
            print("[Seatmap] Performance ID: \(perfId)")
          }
        }
      } catch { self.error = error.localizedDescription }
      self.loading = false
    }
  }
  
  private func fillColorForTier(_ tierCode: String) -> Color {
    switch tierCode {
    case "premium": 
      return Color(.sRGB, red: 0.7, green: 0.5, blue: 0.9, opacity: 1.0)
    case "standard": 
      return Color(.sRGB, red: 0.4, green: 0.6, blue: 0.9, opacity: 1.0)
    case "elevated_premium": 
      return Color(.sRGB, red: 0.2, green: 0.7, blue: 0.6, opacity: 1.0)
    case "elevated_standard": 
      return Color(.sRGB, red: 0.9, green: 0.7, blue: 0.3, opacity: 1.0)
    case "budget": 
      return Color(.sRGB, red: 0.8, green: 0.4, blue: 0.4, opacity: 1.0)
    case "restricted": 
      return Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1.0)
    default:
      return Color(.sRGB, red: 0.6, green: 0.6, blue: 0.6, opacity: 1.0)
    }
  }
  
  private func formatGBP(_ minor: Int) -> String { 
    "£" + String(format: "%.0f", Double(minor)/100.0) 
  }
  
  private func handleSeatTap(seatId: String) async {
    guard let service = seatHoldService, let perfId = performanceId else {
      print("[Seatmap] Missing hold service or performance ID")
      return
    }
    
    // Check if seat is available for selection
    let seatStatus = seatAvailability[seatId] ?? "available"
    if seatStatus != "available" {
      print("[Seatmap] Seat \(seatId) is not available (status: \(seatStatus))")
      return
    }
    
    if selectedSeats.contains(seatId) {
      // User is deselecting - release hold and remove from selection
      _ = await MainActor.run {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          selectedSeats.remove(seatId)
        }
      }
      service.releaseSeats([seatId])
      
    } else {
      // User is selecting - attempt to hold seat
      do {
        try await service.holdSeats([seatId], performanceId: perfId)
        
        // Hold successful - add to selection
        await MainActor.run {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedSeats.insert(seatId)
          }
        }
        
      } catch let error as SeatHoldError {
        await MainActor.run {
          // Show error to user
          switch error {
          case .conflict:
            self.error = "This seat is no longer available"
          case .holdFailed(let reason):
            self.error = "Could not select seat: \(reason)"
          case .networkError:
            self.error = "Network error - please try again"
          }
        }
        
        // Clear error after 3 seconds
        Task {
          try await Task.sleep(nanoseconds: 3_000_000_000)
          await MainActor.run {
            if self.error != nil {
              self.error = nil
            }
          }
        }
        
      } catch {
        await MainActor.run {
          self.error = "Could not select seat: \(error.localizedDescription)"
        }
      }
    }
  }
  
  private struct SeatsLayerView: View {
    let seats: [SeatNode]
    let res: SeatmapTransformResult?
    let canvas: CGSize
    let selectedSeats: Set<String>
    let seatAvailability: [String: String]
    let seatHoldService: SeatHoldService?
    let onSeatTap: (String) -> Void
    
    var body: some View {
      let scale = res?.scale ?? 1.0
      let flippedY = res?.flippedY ?? false
      let dx = res?.dx ?? 0
      let dy = res?.dy ?? 0
      let rPx = res?.seatRadiusPx ?? 8
      let minX = res?.minX ?? 0
      let minY = res?.minY ?? 0
      let worldH = res?.worldH ?? 0
      
      ForEach(Array(seats.enumerated()), id: \.element.id) { index, seat in
        let isLargeBlock = seat.w > 0.05 || seat.h > 0.05
        // Make seats slightly wider than tall for realistic proportions (1.3:1 ratio)
        let seatWidth: CGFloat = isLargeBlock ? seat.w * scale : rPx * 2.6
        let seatHeight: CGFloat = isLargeBlock ? seat.h * scale : rPx * 2.0
        let width: CGFloat = seatWidth
        let height: CGFloat = seatHeight
        let x = seat.x * scale + dx
        let y = flippedY ? (worldH - seat.y) * scale + dy : seat.y * scale + dy
        let cx = x + width / 2.0
        let cy = y + height / 2.0
        
        Button(action: { 
          // Only allow selection of available seats (not reserved/booked)
          if !isReserved(seat) {
            onSeatTap(seat.id) 
          }
        }) {
          Group {
            if isLargeBlock {
              RoundedRectangle(cornerRadius: 8)
                .fill(fillColor(for: seat))
                .overlay(
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.2), lineWidth: 2)
                )
            } else {
              // REALISTIC SEAT SHAPE - Rounded rectangle like actual theater seats
              RoundedRectangle(cornerRadius: 4)
                .fill(fillColor(for: seat))
                .overlay(
                  RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.15), lineWidth: 0.8)
                )
                .overlay(
                  // Add subtle seat texture/highlight
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
            .scaleEffect(selectedSeats.contains(seat.id) ? 1.1 : 1.0)
            .shadow(
              color: selectedSeats.contains(seat.id) ? StageKit.brandEnd.opacity(0.4) : Color.clear,
              radius: selectedSeats.contains(seat.id) ? 8 : 0,
              x: 0, y: 2
            )
        }
        .position(x: cx, y: cy)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedSeats.contains(seat.id))
      }
    }
    
    private func isReserved(_ seat: SeatNode) -> Bool {
      // Check real seat availability from backend
      let status = seatAvailability[seat.id] ?? "available"
      return status != "available" // Any non-available status means reserved/sold/held
    }
    
    private func fillColor(for seat: SeatNode) -> Color {
      // PRIORITY 1: Selected seats = WHITE
      if selectedSeats.contains(seat.id) {
        return Color.white
      }
      
      // PRIORITY 2: Reserved/booked seats = GREY
      if isReserved(seat) {
        return Color.gray.opacity(0.7)
      }
      
      // PRIORITY 3: Available seats = section color from seatmap
      if let colorHex = seat.colorHex, !colorHex.isEmpty {
        return Color(hex: colorHex).opacity(0.85)
      }
      
      // Fallback to price tier color
      guard let priceTier = seat.priceLevelId else { 
        return fillColorForTier("unknown").opacity(0.8)
      }
      return fillColorForTier(priceTier).opacity(0.85)
    }
    
    private func fillColorForTier(_ tierCode: String) -> Color {
      switch tierCode {
      case "premium": 
        return Color(.sRGB, red: 0.7, green: 0.5, blue: 0.9, opacity: 1.0)
      case "standard": 
        return Color(.sRGB, red: 0.4, green: 0.6, blue: 0.9, opacity: 1.0)
      case "elevated_premium": 
        return Color(.sRGB, red: 0.2, green: 0.7, blue: 0.6, opacity: 1.0)
      case "elevated_standard": 
        return Color(.sRGB, red: 0.9, green: 0.7, blue: 0.3, opacity: 1.0)
      case "budget": 
        return Color(.sRGB, red: 0.8, green: 0.4, blue: 0.4, opacity: 1.0)
      case "restricted": 
        return Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1.0)
      default:
        return Color(.sRGB, red: 0.6, green: 0.6, blue: 0.6, opacity: 1.0)
      }
    }
  }
  
  // MARK: - Direct PaymentSheet Integration
  
  private func createOrderAndPresentPaymentSheet(customerEmail: String) {
    print("[Checkout] 🚀 Starting checkout process...")
    print("[Checkout] Selected seats: \(Array(selectedSeats))")
    print("[Checkout] Performance ID: \(performanceId ?? "nil")")
    print("[Checkout] Customer email: \(customerEmail)")
    
    guard !selectedSeats.isEmpty, let performanceId = performanceId else {
      print("[Checkout] ❌ ERROR: No seats selected or performance ID missing")
      return
    }
    
    isCreatingOrder = true
    print("[Checkout] 📝 Creating order for \(selectedSeats.count) seats...")
    
    Task { @MainActor in
      do {
        // Create order request
        let totalAmount = selectedSeats.count * (tiers.first?.amountMinor ?? 2500)
        print("[Checkout] 💰 Total amount: \(totalAmount) (£\(Double(totalAmount)/100))")
        
        let requestBody = CreateOrderRequest(
          performance_id: performanceId,
          seat_ids: Array(selectedSeats),
          currency: "GBP", 
          total_minor: totalAmount,
          customer_email: customerEmail
        )
        
        print("[Checkout] 📤 Sending order request to API...")
        
        // Create order via API
        let bodyData = try JSONEncoder().encode(requestBody)
        let (responseData, _) = try await app.api.request(
          path: "/v1/orders",
          method: "POST",
          body: bodyData,
          headers: ["Idempotency-Key": "order_\(UUID().uuidString)"]
        )
        
        print("[Checkout] ✅ Order API response received")
        
        let orderResponse = try JSONDecoder().decode(CreateOrderResponse.self, from: responseData)
        print("[Checkout] 🎯 Order \(orderResponse.order_id) created successfully")
        
        // Store order response for success screen
        lastOrderResponse = orderResponse
        
        // Configure Stripe API
        print("[Checkout] 🔧 Configuring Stripe API...")
        StripeAPI.defaultPublishableKey = Config.stripePublishableKey
        
        // Create PaymentSheet configuration
        print("[Checkout] ⚙️ Creating PaymentSheet configuration...")
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "LastMinuteLive"
        configuration.allowsDelayedPaymentMethods = false
        
        // Configure email collection for ticket confirmation
        // NOTE: Billing details collection might not be available in this Stripe SDK version
        print("[Checkout] 📧 Email collection will use Stripe's default behavior...")
        // TODO: Upgrade Stripe SDK version to enable custom billing details collection
        // var billingConfig = PaymentSheet.BillingDetailsCollectionConfiguration()
        // billingConfig.email = .always
        // configuration.billingDetailsCollectionConfiguration = billingConfig
        
        // Add Apple Pay if available
        if PKPaymentAuthorizationViewController.canMakePayments() {
          print("[Checkout] 🍎 Apple Pay is available, adding to configuration")
          configuration.applePay = .init(
            merchantId: Config.merchantIdentifier,
            merchantCountryCode: Config.countryCode
          )
        } else {
          print("[Checkout] ⚠️ Apple Pay not available")
        }
        
        // Create the official PaymentSheet
        print("[Checkout] 💳 Creating PaymentSheet with client secret: \(orderResponse.client_secret.prefix(20))...")
        paymentSheet = PaymentSheet(
          paymentIntentClientSecret: orderResponse.client_secret,
          configuration: configuration
        )
        
        // Present PaymentSheet
        print("[Checkout] 🎬 Setting showCheckout = true to present PaymentSheet")
        showCheckout = true
        print("[Checkout] ✨ PaymentSheet should now be presented!")
        
      } catch {
        print("[Checkout] ❌ ERROR: Order creation failed: \(error)")
        if let apiError = error as? ApiError {
          print("[Checkout] API Error details: \(apiError)")
        }
      }
      
      print("[Checkout] 🏁 Finished checkout process, isCreatingOrder = false")
      isCreatingOrder = false
    }
  }
  
  private func handlePaymentResult(_ result: PaymentSheetResult) {
    switch result {
    case .completed:
      print("[PaymentSheet] Payment completed successfully!")
      
      // Prepare success data
      if let orderResponse = lastOrderResponse {
        // Get the actual seat node data for proper formatting
        let currentSelectedSeatNodes = model?.seats.filter { selectedSeats.contains($0.id) } ?? []
        
        successData = PaymentSuccessData(
          orderId: orderResponse.order_id,
          totalAmount: orderResponse.total_amount,
          currency: orderResponse.currency,
          seatIds: Array(selectedSeats),
          seatNodes: currentSelectedSeatNodes, // Pass actual seat node data
          performanceName: show.title,
          performanceDate: formatPerformanceDate(show.nextPerformance ?? ""),
          venueName: show.venue,
          venueCoordinates: getVenueCoordinates(for: show.venue),
          customerEmail: extractEmailFromPaymentSheet(),
          paymentMethod: "Card", // Default for now - could be enhanced
          purchaseDate: formatCurrentDateTime()
        )
        
        // Clear selected seats
        selectedSeats.removeAll()
        
        // Show success screen
        showSuccessScreen = true
      }
      
    case .canceled:
      print("[PaymentSheet] Payment was canceled")
      // Keep seats selected, user might try again
      
    case .failed(let error):
      print("[PaymentSheet] Payment failed: \(error)")
      // Show error message to user
      // TODO: Show error alert to user
    }
  }
  
  // Helper function to format performance date
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
  
  // Placeholder for extracting email from PaymentSheet
  // This is a limitation - Stripe doesn't expose the entered email directly
  private func extractEmailFromPaymentSheet() -> String? {
    // For now, return nil - in a real app, you might store this separately
    // or pass it from a user profile
    return nil
  }
  
  // Get venue coordinates for Apple Maps integration
  private func getVenueCoordinates(for venueName: String) -> CLLocationCoordinate2D? {
    switch venueName.lowercased() {
    case "victoria palace theatre":
      return CLLocationCoordinate2D(latitude: 51.4942, longitude: -0.1358)
    case "lyceum theatre":
      return CLLocationCoordinate2D(latitude: 51.5115, longitude: -0.1203)
    case "palace theatre":
      return CLLocationCoordinate2D(latitude: 51.5135, longitude: -0.1286)
    default:
      // Default to London center if venue not found
      return CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    }
  }
  
  // Format current date and time for purchase timestamp
  private func formatCurrentDateTime() -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: Date())
  }
}

private extension Color {
  static let gold = Color(.sRGB, red: 0.85, green: 0.65, blue: 0.13, opacity: 1.0)
  
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
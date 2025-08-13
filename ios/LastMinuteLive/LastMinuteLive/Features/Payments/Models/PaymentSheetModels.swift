import Foundation
import SwiftUI

// MARK: - Payment Result

enum PaymentResult {
  case success
  case cancelled
  case failed
  
  var message: String {
    switch self {
    case .success:
      return "Payment successful! Your seats are confirmed. 🎉"
    case .cancelled:
      return "Payment was cancelled."
    case .failed:
      return "Payment failed. Please try again."
    }
  }
}

// MARK: - Order Summary

struct OrderSummary {
  let seatCount: Int
  let totalAmount: Int // In minor units (pence, cents)
  let currency: String
  let processingFeeIncluded: Bool
  
  var formattedTotal: String {
    switch currency.uppercased() {
    case "GBP":
      return String(format: "£%.2f", Double(totalAmount) / 100)
    case "USD":
      return String(format: "$%.2f", Double(totalAmount) / 100)
    case "EUR":
      return String(format: "€%.2f", Double(totalAmount) / 100)
    default:
      return String(format: "%.2f %@", Double(totalAmount) / 100, currency)
    }
  }
  
  var seatDescription: String {
    return "\(seatCount) seat\(seatCount == 1 ? "" : "s")"
  }
  
  var processingFeeDescription: String {
    return processingFeeIncluded ? "Included" : "Not included"
  }
}

// MARK: - Payment State

enum PaymentState {
  case idle
  case processing
  case completed(PaymentResult)
  
  var isProcessing: Bool {
    if case .processing = self {
      return true
    }
    return false
  }
  
  var isIdle: Bool {
    if case .idle = self {
      return true
    }
    return false
  }
}
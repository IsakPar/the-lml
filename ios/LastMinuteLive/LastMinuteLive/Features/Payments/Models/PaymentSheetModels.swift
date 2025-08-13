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

// MARK: - Payment Method Type

enum PaymentMethodType {
  case card
  case applePay
  
  var displayName: String {
    switch self {
    case .card:
      return "Credit or Debit Card"
    case .applePay:
      return "Apple Pay"
    }
  }
  
  var iconName: String {
    switch self {
    case .card:
      return "creditcard"
    case .applePay:
      return "applelogo"
    }
  }
}

// MARK: - Payment Form Data

struct PaymentFormData {
  var cardNumber: String = ""
  var expiryDate: String = ""
  var cvcCode: String = ""
  var email: String = ""
  var nameOnCard: String = ""
  var selectedPaymentMethod: PaymentMethodType = .card
  
  // Computed properties
  var formattedCardNumber: String {
    return CardInputFormatting.formatCardNumber(cardNumber)
  }
  
  var cleanCardNumber: String {
    return CardInputFormatting.cleanCardNumber(cardNumber)
  }
  
  var formattedExpiry: String {
    return CardInputFormatting.formatExpiryDate(expiryDate)
  }
  
  var formattedCVC: String {
    return CardInputFormatting.formatCVC(cvcCode)
  }
  
  var formattedName: String {
    return CardInputFormatting.formatCardholderName(nameOnCard)
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

// MARK: - Payment Configuration

struct PaymentConfiguration {
  let clientSecret: String
  let orderSummary: OrderSummary
  let stripePublishableKey: String
  let appleMerchantIdentifier: String?
  let isApplePayEnabled: Bool
  
  init(
    clientSecret: String,
    orderSummary: OrderSummary,
    stripePublishableKey: String,
    appleMerchantIdentifier: String? = nil,
    isApplePayEnabled: Bool = true
  ) {
    self.clientSecret = clientSecret
    self.orderSummary = orderSummary
    self.stripePublishableKey = stripePublishableKey
    self.appleMerchantIdentifier = appleMerchantIdentifier
    self.isApplePayEnabled = isApplePayEnabled
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

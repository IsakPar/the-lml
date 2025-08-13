import Foundation

// MARK: - Validation Results

struct ValidationResult {
  let isValid: Bool
  let errorMessage: String?
  
  static let valid = ValidationResult(isValid: true, errorMessage: nil)
  static func invalid(_ message: String) -> ValidationResult {
    return ValidationResult(isValid: false, errorMessage: message)
  }
}

struct CardValidationErrors {
  var cardNumber: String?
  var expiry: String?
  var cvc: String?
  var email: String?
  
  var hasErrors: Bool {
    return cardNumber != nil || expiry != nil || cvc != nil || email != nil
  }
}

// MARK: - Validation Functions

enum CardInputValidation {
  
  // MARK: - Card Number Validation
  
  static func validateCardNumber(_ cardNumber: String) -> ValidationResult {
    let digits = cardNumber.replacingOccurrences(of: " ", with: "")
    
    if digits.isEmpty {
      return .valid // Allow empty for progressive validation
    }
    
    if digits.count < 13 {
      return .invalid("Card number too short")
    }
    
    if digits.count > 19 {
      return .invalid("Card number too long")
    }
    
    // Basic Luhn algorithm validation (optional enhancement)
    return .valid
  }
  
  // MARK: - Expiry Date Validation
  
  static func validateExpiryDate(_ expiryDate: String) -> ValidationResult {
    if expiryDate.isEmpty {
      return .valid // Allow empty for progressive validation
    }
    
    let components = expiryDate.split(separator: "/")
    guard components.count == 2,
          let month = Int(components[0]),
          let year = Int(components[1]) else {
      return .invalid("Invalid format (MM/YY)")
    }
    
    if month < 1 || month > 12 {
      return .invalid("Invalid month")
    }
    
    let currentYear = Calendar.current.component(.year, from: Date()) % 100
    let currentMonth = Calendar.current.component(.month, from: Date())
    
    if year < currentYear || (year == currentYear && month < currentMonth) {
      return .invalid("Card expired")
    }
    
    return .valid
  }
  
  // MARK: - CVC Validation
  
  static func validateCVC(_ cvc: String) -> ValidationResult {
    if cvc.isEmpty {
      return .valid // Allow empty for progressive validation
    }
    
    if cvc.count < 3 {
      return .invalid("CVC too short")
    }
    
    if cvc.count > 4 {
      return .invalid("CVC too long")
    }
    
    return .valid
  }
  
  // MARK: - Email Validation
  
  static func validateEmail(_ email: String) -> ValidationResult {
    if email.isEmpty {
      return .valid // Allow empty for progressive validation
    }
    
    if !email.contains("@") || !email.contains(".") {
      return .invalid("Invalid email format")
    }
    
    // Enhanced email validation (basic)
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    
    if !emailTest.evaluate(with: email) {
      return .invalid("Please enter a valid email address")
    }
    
    return .valid
  }
  
  // MARK: - Form Validation
  
  static func validatePaymentForm(
    cardNumber: String,
    expiryDate: String, 
    cvc: String,
    email: String,
    nameOnCard: String
  ) -> (isValid: Bool, errors: CardValidationErrors) {
    
    var errors = CardValidationErrors()
    
    // Validate each field (only show errors for non-empty fields)
    let cardResult = validateCardNumber(cardNumber)
    if !cardResult.isValid && !cardNumber.isEmpty {
      errors.cardNumber = cardResult.errorMessage
    }
    
    let expiryResult = validateExpiryDate(expiryDate)
    if !expiryResult.isValid && !expiryDate.isEmpty {
      errors.expiry = expiryResult.errorMessage
    }
    
    let cvcResult = validateCVC(cvc)
    if !cvcResult.isValid && !cvc.isEmpty {
      errors.cvc = cvcResult.errorMessage
    }
    
    let emailResult = validateEmail(email)
    if !emailResult.isValid && !email.isEmpty {
      errors.email = emailResult.errorMessage
    }
    
    // Form is valid if all required fields are filled and have no errors
    let isFormComplete = !cardNumber.isEmpty && 
                        cardNumber.replacingOccurrences(of: " ", with: "").count >= 13 &&
                        !expiryDate.isEmpty && expiryDate.count >= 5 &&
                        !cvc.isEmpty && cvc.count >= 3 &&
                        !email.isEmpty && !nameOnCard.isEmpty
    
    let isValid = isFormComplete && !errors.hasErrors
    
    return (isValid: isValid, errors: errors)
  }
}

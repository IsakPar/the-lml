import Foundation

// MARK: - Card Input Formatting Functions

enum CardInputFormatting {
  
  // MARK: - Card Number Formatting
  
  /// Formats card number with spaces every 4 digits (e.g., "1234 5678 9012 3456")
  static func formatCardNumber(_ input: String) -> String {
    // Remove all non-digit characters
    let digits = input.filter { $0.isWholeNumber }
    
    // Limit to 19 digits max (longest card number)
    let limitedDigits = String(digits.prefix(19))
    
    // Add spaces every 4 digits
    let formatted = limitedDigits.enumerated().compactMap { index, character in
      return (index > 0 && index % 4 == 0) ? " \(character)" : "\(character)"
    }.joined()
    
    return formatted
  }
  
  /// Removes formatting from card number (spaces, dashes, etc.)
  static func cleanCardNumber(_ input: String) -> String {
    return input.replacingOccurrences(of: " ", with: "")
               .replacingOccurrences(of: "-", with: "")
               .filter { $0.isWholeNumber }
  }
  
  // MARK: - Expiry Date Formatting
  
  /// Formats expiry date as MM/YY
  static func formatExpiryDate(_ input: String) -> String {
    // Remove all non-digit characters
    let digits = input.filter { $0.isWholeNumber }
    
    // Limit to 4 digits max (MMYY)
    let limitedDigits = String(digits.prefix(4))
    
    if limitedDigits.count <= 2 {
      return limitedDigits
    } else {
      let month = String(limitedDigits.prefix(2))
      let year = String(limitedDigits.dropFirst(2))
      return "\(month)/\(year)"
    }
  }
  
  /// Extracts month and year from formatted expiry string
  static func parseExpiryDate(_ formatted: String) -> (month: Int?, year: Int?) {
    let components = formatted.split(separator: "/")
    guard components.count == 2 else {
      return (month: nil, year: nil)
    }
    
    let month = Int(components[0])
    let yearString = String(components[1])
    
    // Convert YY to YYYY format
    var year: Int?
    if let shortYear = Int(yearString) {
      year = shortYear < 50 ? 2000 + shortYear : 1900 + shortYear
    }
    
    return (month: month, year: year)
  }
  
  // MARK: - CVC Formatting
  
  /// Formats CVC (removes non-digits, limits to 4 characters)
  static func formatCVC(_ input: String) -> String {
    let digits = input.filter { $0.isWholeNumber }
    return String(digits.prefix(4)) // Max 4 digits for American Express
  }
  
  // MARK: - Name Formatting
  
  /// Formats cardholder name (trims whitespace, title case)
  static func formatCardholderName(_ input: String) -> String {
    return input.trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
  }
  
  // MARK: - Phone Number Formatting (if needed)
  
  /// Formats phone number with standard formatting
  static func formatPhoneNumber(_ input: String) -> String {
    let digits = input.filter { $0.isWholeNumber }
    
    switch digits.count {
    case 7:
      let area = String(digits.prefix(3))
      let number = String(digits.suffix(4))
      return "\(area)-\(number)"
    case 10:
      let area = String(digits.prefix(3))
      let exchange = String(digits.dropFirst(3).prefix(3))
      let number = String(digits.suffix(4))
      return "(\(area)) \(exchange)-\(number)"
    case 11:
      let country = String(digits.prefix(1))
      let area = String(digits.dropFirst(1).prefix(3))
      let exchange = String(digits.dropFirst(4).prefix(3))
      let number = String(digits.suffix(4))
      return "+\(country) (\(area)) \(exchange)-\(number)"
    default:
      return digits
    }
  }
  
  // MARK: - Utility Functions
  
  /// Removes all formatting characters and returns only digits
  static func digitsOnly(_ input: String) -> String {
    return input.filter { $0.isWholeNumber }
  }
  
  /// Checks if string contains only digits
  static func isNumericOnly(_ input: String) -> Bool {
    return !input.isEmpty && input.allSatisfy { $0.isWholeNumber }
  }
  
  /// Limits string to maximum length
  static func limitLength(_ input: String, to maxLength: Int) -> String {
    return String(input.prefix(maxLength))
  }
}

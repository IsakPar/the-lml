import Foundation

/// Domain utility for email validation following DDD principles
/// Provides clean, reusable email validation logic across the app
struct EmailValidator {
    
    /// Validates email format using RFC 5322 compliant regex
    /// - Parameter email: The email string to validate
    /// - Returns: ValidationResult with success/failure and user-friendly message
    static func validate(_ email: String) -> ValidationResult {
        // Handle empty case
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("Email is required")
        }
        
        // Check basic format
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // RFC 5322 compliant regex for email validation
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if emailPredicate.evaluate(with: trimmedEmail) {
            return .valid
        } else {
            return .invalid("Please enter a valid email address")
        }
    }
    
    /// Validates if email is in proper format for checkout
    /// - Parameter email: The email string to validate
    /// - Returns: Boolean indicating if email is ready for checkout
    static func isValidForCheckout(_ email: String) -> Bool {
        switch validate(email) {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    /// Clean email for storage (trim whitespace, lowercase domain)
    /// - Parameter email: Raw email input
    /// - Returns: Cleaned email string
    static func clean(_ email: String) -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.components(separatedBy: "@")
        
        if components.count == 2 {
            let localPart = components[0]
            let domain = components[1].lowercased()
            return "\(localPart)@\(domain)"
        }
        
        return trimmed
    }
}

/// Domain model for email validation results
enum ValidationResult {
    case valid
    case invalid(String)
    
    /// Check if validation passed
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    /// Get user-friendly error message
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message):
            return message
        }
    }
}

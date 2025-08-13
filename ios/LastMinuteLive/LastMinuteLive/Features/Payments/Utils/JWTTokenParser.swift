import Foundation

// MARK: - JWT Token Parsing Utilities

enum JWTTokenParser {
  
  // MARK: - Token Parsing
  
  /// Extracts email from JWT access token
  static func extractEmail(from token: String) -> String? {
    guard let payload = parseJWTPayload(token) else { return nil }
    
    // Look for common email fields in JWT payload
    return payload["email"] as? String ?? 
           payload["sub"] as? String ?? 
           payload["preferred_username"] as? String ??
           payload["username"] as? String
  }
  
  /// Extracts user name from JWT access token
  static func extractUserName(from token: String) -> String? {
    guard let payload = parseJWTPayload(token) else { return nil }
    
    // Look for common name fields
    return payload["name"] as? String ??
           payload["given_name"] as? String ??
           payload["preferred_name"] as? String ??
           payload["display_name"] as? String
  }
  
  /// Extracts user ID from JWT access token
  static func extractUserID(from token: String) -> String? {
    guard let payload = parseJWTPayload(token) else { return nil }
    
    return payload["user_id"] as? String ??
           payload["uid"] as? String ??
           payload["sub"] as? String
  }
  
  /// Checks if JWT token is expired
  static func isTokenExpired(_ token: String) -> Bool {
    guard let payload = parseJWTPayload(token),
          let exp = payload["exp"] as? Double else {
      return true // Assume expired if we can't parse
    }
    
    let expirationDate = Date(timeIntervalSince1970: exp)
    return expirationDate <= Date()
  }
  
  // MARK: - Core Parsing Functions
  
  /// Parses JWT payload and returns dictionary
  static func parseJWTPayload(_ token: String) -> [String: Any]? {
    // JWT tokens are in format: header.payload.signature
    let components = token.components(separatedBy: ".")
    guard components.count >= 2 else { return nil }
    
    let payloadBase64 = components[1]
    
    guard let payloadData = base64URLDecode(payloadBase64),
          let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
      return nil
    }
    
    return payload
  }
  
  /// Parses JWT header and returns dictionary
  static func parseJWTHeader(_ token: String) -> [String: Any]? {
    let components = token.components(separatedBy: ".")
    guard components.count >= 1 else { return nil }
    
    let headerBase64 = components[0]
    
    guard let headerData = base64URLDecode(headerBase64),
          let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any] else {
      return nil
    }
    
    return header
  }
  
  // MARK: - Base64 URL Decoding
  
  /// Decodes Base64 URL encoded string (JWT standard)
  static func base64URLDecode(_ base64URL: String) -> Data? {
    // Add padding if needed for base64 decoding
    var paddedPayload = base64URL
    let padding = 4 - (base64URL.count % 4)
    if padding != 4 {
      paddedPayload += String(repeating: "=", count: padding)
    }
    
    // Replace URL-safe characters with standard base64 characters
    paddedPayload = paddedPayload
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    
    return Data(base64Encoded: paddedPayload)
  }
  
  // MARK: - Token Validation
  
  /// Basic JWT format validation (doesn't verify signature)
  static func isValidJWTFormat(_ token: String) -> Bool {
    let components = token.components(separatedBy: ".")
    return components.count == 3 || components.count == 5 // Standard JWT or custom format
  }
  
  /// Extracts token type from JWT header
  static func getTokenType(_ token: String) -> String? {
    guard let header = parseJWTHeader(token) else { return nil }
    return header["typ"] as? String
  }
  
  /// Extracts algorithm from JWT header
  static func getAlgorithm(_ token: String) -> String? {
    guard let header = parseJWTHeader(token) else { return nil }
    return header["alg"] as? String
  }
}

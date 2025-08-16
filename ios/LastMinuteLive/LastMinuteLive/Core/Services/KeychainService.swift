import Foundation
import Security

/// Secure keychain storage service following DDD principles
/// Handles secure storage of tokens, user data, and sensitive information
@MainActor
final class KeychainService: ObservableObject {
    
    // MARK: - Constants
    
    private enum KeychainKey {
        static let accessToken = "lml_access_token"
        static let refreshToken = "lml_refresh_token" 
        static let userEmail = "lml_user_email"
        static let userId = "lml_user_id"
        static let appleUserIdentifier = "lml_apple_user_id"
        static let googleUserIdentifier = "lml_google_user_id"
        static let sessionExpiry = "lml_session_expiry"
    }
    
    private let service = "com.lastminutelive.app"
    
    // MARK: - Token Management
    
    /// Store access token securely in keychain
    func storeAccessToken(_ token: String) {
        store(key: KeychainKey.accessToken, value: token)
        print("[Keychain] 🔐 Access token stored securely")
    }
    
    /// Retrieve access token from keychain
    func getAccessToken() -> String? {
        let token = retrieve(key: KeychainKey.accessToken)
        if token != nil {
            print("[Keychain] ✅ Access token retrieved")
        } else {
            print("[Keychain] ❌ No access token found")
        }
        return token
    }
    
    /// Store refresh token securely in keychain
    func storeRefreshToken(_ token: String) {
        store(key: KeychainKey.refreshToken, value: token)
        print("[Keychain] 🔐 Refresh token stored securely")
    }
    
    /// Retrieve refresh token from keychain
    func getRefreshToken() -> String? {
        return retrieve(key: KeychainKey.refreshToken)
    }
    
    // MARK: - User Data Management
    
    /// Store user email securely
    func storeUserEmail(_ email: String) {
        store(key: KeychainKey.userEmail, value: email)
        print("[Keychain] 📧 User email stored: \(email)")
    }
    
    /// Retrieve user email
    func getUserEmail() -> String? {
        return retrieve(key: KeychainKey.userEmail)
    }
    
    /// Store user ID securely
    func storeUserId(_ userId: String) {
        store(key: KeychainKey.userId, value: userId)
        print("[Keychain] 👤 User ID stored")
    }
    
    /// Retrieve user ID
    func getUserId() -> String? {
        return retrieve(key: KeychainKey.userId)
    }
    
    // MARK: - Provider-Specific Identifiers
    
    /// Store Apple user identifier
    func storeAppleUserIdentifier(_ identifier: String) {
        store(key: KeychainKey.appleUserIdentifier, value: identifier)
        print("[Keychain] 🍎 Apple user identifier stored")
    }
    
    /// Retrieve Apple user identifier
    func getAppleUserIdentifier() -> String? {
        return retrieve(key: KeychainKey.appleUserIdentifier)
    }
    
    /// Store Google user identifier
    func storeGoogleUserIdentifier(_ identifier: String) {
        store(key: KeychainKey.googleUserIdentifier, value: identifier)
        print("[Keychain] 🌐 Google user identifier stored")
    }
    
    /// Retrieve Google user identifier
    func getGoogleUserIdentifier() -> String? {
        return retrieve(key: KeychainKey.googleUserIdentifier)
    }
    
    // MARK: - Session Management
    
    /// Store session expiry time
    func storeSessionExpiry(_ expiry: Date) {
        let timestamp = expiry.timeIntervalSince1970
        store(key: KeychainKey.sessionExpiry, value: String(timestamp))
        print("[Keychain] ⏰ Session expiry stored: \(expiry)")
    }
    
    /// Get session expiry time
    func getSessionExpiry() -> Date? {
        guard let timestampString = retrieve(key: KeychainKey.sessionExpiry),
              let timestamp = Double(timestampString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// Check if current session is valid (not expired)
    func isSessionValid() -> Bool {
        guard let expiry = getSessionExpiry() else {
            print("[Keychain] ❌ No session expiry found")
            return false
        }
        
        let isValid = expiry > Date()
        print("[Keychain] \(isValid ? "✅" : "❌") Session valid: \(isValid)")
        return isValid
    }
    
    // MARK: - Clear Data
    
    /// Clear all user data from keychain (logout)
    func clearAllUserData() {
        let keys = [
            KeychainKey.accessToken,
            KeychainKey.refreshToken,
            KeychainKey.userEmail,
            KeychainKey.userId,
            KeychainKey.appleUserIdentifier,
            KeychainKey.googleUserIdentifier,
            KeychainKey.sessionExpiry
        ]
        
        keys.forEach { key in
            delete(key: key)
        }
        
        print("[Keychain] 🧹 All user data cleared from keychain")
    }
    
    /// Clear only tokens (for token refresh)
    func clearTokens() {
        delete(key: KeychainKey.accessToken)
        delete(key: KeychainKey.refreshToken)
        print("[Keychain] 🔄 Tokens cleared for refresh")
    }
    
    // MARK: - Private Keychain Operations
    
    private func store(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("[Keychain] ⚠️ Failed to store \(key): \(status)")
        }
    }
    
    private func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

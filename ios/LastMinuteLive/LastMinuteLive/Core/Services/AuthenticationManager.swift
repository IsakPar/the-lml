import Foundation
import SwiftUI
import AuthenticationServices
import Combine

/// Central authentication manager following DDD principles
/// Manages authentication state, session persistence, and user data
@MainActor
final class AuthenticationManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var authenticationState: AuthenticationState = .unauthenticated
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var lastError: String?
    
    // MARK: - Dependencies
    
    private let keychainService = KeychainService()
    private let apiClient: ApiClient
    
    // MARK: - Authentication State
    
    enum AuthenticationState {
        case unauthenticated
        case authenticated(User)
        case expired
        
        var isAuthenticated: Bool {
            if case .authenticated = self {
                return true
            }
            return false
        }
        
        var user: User? {
            if case .authenticated(let user) = self {
                return user
            }
            return nil
        }
    }
    
    // MARK: - User Model
    
    struct User: Codable, Identifiable {
        let id: String
        let email: String
        let name: String?
        let provider: AuthProvider
        let createdAt: String
        let isVerified: Bool
        
        enum AuthProvider: String, Codable {
            case email = "email"
            case apple = "apple"
            case google = "google"
        }
    }
    
    // MARK: - Initialization
    
    init(apiClient: ApiClient) {
        self.apiClient = apiClient
        
        // Attempt to restore session on init
        Task {
            await restoreSession()
        }
    }
    
    // MARK: - Session Management
    
    /// Restore authentication session from keychain
    func restoreSession() async {
        print("[Auth] 🔄 Attempting to restore session...")
        
        guard keychainService.isSessionValid(),
              let accessToken = keychainService.getAccessToken(),
              let email = keychainService.getUserEmail(),
              let userId = keychainService.getUserId() else {
            
            print("[Auth] ❌ No valid session found")
            await clearSession()
            return
        }
        
        // Verify token with backend
        do {
            isLoading = true
            let user = try await verifyTokenAndGetUser(accessToken: accessToken)
            
            await authenticateUser(user)
            print("[Auth] ✅ Session restored successfully for: \(user.email)")
            
        } catch {
            print("[Auth] ❌ Session verification failed: \(error)")
            await clearSession()
        }
        
        isLoading = false
    }
    
    /// Clear current session and logout
    func logout() async {
        print("[Auth] 👋 Logging out user...")
        
        keychainService.clearAllUserData()
        
        authenticationState = .unauthenticated
        currentUser = nil
        lastError = nil
        
        print("[Auth] ✅ Logout completed")
    }
    
    // MARK: - Email Authentication
    
    /// Authenticate with email and password
    func authenticateWithEmail(_ email: String, password: String) async -> Bool {
        print("[Auth] 📧 Attempting email authentication for: \(email)")
        
        isLoading = true
        lastError = nil
        
        do {
            let authResponse = try await performEmailLogin(email: email, password: password)
            await storeAuthenticationData(authResponse)
            
            let user = User(
                id: authResponse.userId,
                email: email,
                name: authResponse.name,
                provider: .email,
                createdAt: authResponse.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                isVerified: authResponse.isVerified ?? true
            )
            
            await authenticateUser(user)
            
            print("[Auth] ✅ Email authentication successful")
            isLoading = false
            return true
            
        } catch {
            print("[Auth] ❌ Email authentication failed: \(error)")
            lastError = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Apple Sign In
    
    /// Handle Apple Sign In result
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async -> Bool {
        print("[Auth] 🍎 Processing Apple Sign In result...")
        
        isLoading = true
        lastError = nil
        
        switch result {
        case .success(let authorization):
            return await processAppleAuthorization(authorization)
            
        case .failure(let error):
            print("[Auth] ❌ Apple Sign In failed: \(error)")
            lastError = "Apple Sign In failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    private func processAppleAuthorization(_ authorization: ASAuthorization) async -> Bool {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            lastError = "Invalid Apple credentials"
            isLoading = false
            return false
        }
        
        // Extract user data
        let userIdentifier = appleIDCredential.user
        let email = appleIDCredential.email ?? keychainService.getUserEmail() // Use stored email if not provided
        let fullName = appleIDCredential.fullName
        
        guard let email = email else {
            print("[Auth] ❌ No email available from Apple Sign In")
            lastError = "Email is required for Apple Sign In"
            isLoading = false
            return false
        }
        
        // Store Apple user identifier
        keychainService.storeAppleUserIdentifier(userIdentifier)
        
        do {
            // Send to backend for verification
            let authResponse = try await performAppleSignIn(
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName,
                identityToken: appleIDCredential.identityToken,
                authorizationCode: appleIDCredential.authorizationCode
            )
            
            await storeAuthenticationData(authResponse)
            
            let user = User(
                id: authResponse.userId,
                email: email,
                name: formatAppleName(fullName) ?? authResponse.name,
                provider: .apple,
                createdAt: authResponse.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                isVerified: true // Apple accounts are always verified
            )
            
            await authenticateUser(user)
            
            print("[Auth] ✅ Apple Sign In successful for: \(email)")
            isLoading = false
            return true
            
        } catch {
            print("[Auth] ❌ Apple Sign In backend verification failed: \(error)")
            lastError = "Apple Sign In failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    // MARK: - Google Sign In (Placeholder for future implementation)
    
    /// Handle Google Sign In (to be implemented with Google SDK)
    func authenticateWithGoogle() async -> Bool {
        print("[Auth] 🌐 Google Sign In not yet implemented")
        lastError = "Google Sign In coming soon!"
        return false
    }
    
    // MARK: - Private Helpers
    
    private func authenticateUser(_ user: User) async {
        currentUser = user
        authenticationState = .authenticated(user)
        
        // Store user email in keychain for future use
        keychainService.storeUserEmail(user.email)
        keychainService.storeUserId(user.id)
        
        print("[Auth] ✅ User authenticated: \(user.email) (\(user.provider.rawValue))")
    }
    
    private func storeAuthenticationData(_ response: AuthResponse) async {
        keychainService.storeAccessToken(response.accessToken)
        
        if let refreshToken = response.refreshToken {
            keychainService.storeRefreshToken(refreshToken)
        }
        
        // Store session expiry (default to 24 hours if not provided)
        let expiryDate = response.expiresAt ?? Date().addingTimeInterval(24 * 60 * 60)
        keychainService.storeSessionExpiry(expiryDate)
    }
    
    private func clearSession() async {
        keychainService.clearAllUserData()
        authenticationState = .unauthenticated
        currentUser = nil
    }
    
    private func formatAppleName(_ fullName: PersonNameComponents?) -> String? {
        guard let fullName = fullName else { return nil }
        
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        return formatter.string(from: fullName)
    }
    
    // MARK: - API Calls
    
    private func performEmailLogin(email: String, password: String) async throws -> AuthResponse {
        let requestBody: [String: Any] = [
            "email": email,
            "password": password,
            "grant_type": "password"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await apiClient.request(
            path: "/v1/auth/login",
            method: "POST",
            body: jsonData,
            headers: ["Content-Type": "application/json"]
        )
        
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
    
    private func performAppleSignIn(
        userIdentifier: String,
        email: String,
        fullName: PersonNameComponents?,
        identityToken: Data?,
        authorizationCode: Data?
    ) async throws -> AuthResponse {
        
        var requestBody: [String: Any] = [
            "provider": "apple",
            "provider_user_id": userIdentifier,
            "email": email
        ]
        
        if let fullName = fullName {
            let name = formatAppleName(fullName)
            requestBody["name"] = name
        }
        
        if let identityToken = identityToken,
           let tokenString = String(data: identityToken, encoding: .utf8) {
            requestBody["identity_token"] = tokenString
        }
        
        if let authorizationCode = authorizationCode,
           let codeString = String(data: authorizationCode, encoding: .utf8) {
            requestBody["authorization_code"] = codeString
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await apiClient.request(
            path: "/v1/auth/apple",
            method: "POST",
            body: jsonData,
            headers: ["Content-Type": "application/json"]
        )
        
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
    
    private func verifyTokenAndGetUser(accessToken: String) async throws -> User {
        let (data, _) = try await apiClient.request(
            path: "/v1/users/profile",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
        
        let userResponse = try JSONDecoder().decode(UserProfileResponse.self, from: data)
        
        return User(
            id: userResponse.id,
            email: userResponse.email,
            name: userResponse.name,
            provider: AuthenticationManager.User.AuthProvider(rawValue: userResponse.provider) ?? .email,
            createdAt: userResponse.createdAt,
            isVerified: userResponse.isVerified
        )
    }
}

// MARK: - Response Models

private struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let userId: String
    let name: String?
    let createdAt: String?
    let isVerified: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case userId = "user_id"
        case name, createdAt, isVerified
    }
}

private struct UserProfileResponse: Codable {
    let id: String
    let email: String
    let name: String?
    let provider: String
    let createdAt: String
    let isVerified: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id, email, name, provider, isVerified
        case createdAt = "created_at"
    }
}

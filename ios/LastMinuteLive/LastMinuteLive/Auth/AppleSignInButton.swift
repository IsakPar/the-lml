import SwiftUI
import AuthenticationServices

struct AppleSignInButton: UIViewRepresentable {
  // Legacy callbacks for backward compatibility
  let onToken: ((String) -> Void)?
  let onError: ((Error?) -> Void)?
  
  // New result-based callback for enhanced authentication
  let onResult: ((Result<ASAuthorization, Error>) -> Void)?

  // Legacy initializer
  init(onToken: @escaping (String) -> Void, onError: @escaping (Error?) -> Void) {
    self.onToken = onToken
    self.onError = onError
    self.onResult = nil
  }
  
  // New initializer with result callback
  init(onResult: @escaping (Result<ASAuthorization, Error>) -> Void) {
    self.onToken = nil
    self.onError = nil
    self.onResult = onResult
  }

  func makeCoordinator() -> Coordinator { 
    Coordinator(onToken: onToken, onError: onError, onResult: onResult) 
  }

  func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
    let btn = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
    btn.cornerRadius = 12
    btn.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
    return btn
  }

  func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

  final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let onToken: ((String) -> Void)?
    let onError: ((Error?) -> Void)?
    let onResult: ((Result<ASAuthorization, Error>) -> Void)?
    
    init(onToken: ((String) -> Void)?, onError: ((Error?) -> Void)?, onResult: ((Result<ASAuthorization, Error>) -> Void)?) {
      self.onToken = onToken
      self.onError = onError
      self.onResult = onResult
    }

    @objc func handleTap() {
      let provider = ASAuthorizationAppleIDProvider()
      let request = provider.createRequest()
      request.requestedScopes = [.fullName, .email]
      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
      return UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
      // New result-based callback (preferred)
      if let onResult = onResult {
        onResult(.success(authorization))
        return
      }
      
      // Legacy token-based callback (for backward compatibility)
      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8) else {
        onError?(nil)
        return
      }
      onToken?(token)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
      // New result-based callback (preferred)
      if let onResult = onResult {
        onResult(.failure(error))
        return
      }
      
      // Legacy error callback (for backward compatibility)
      onError?(error)
    }
  }
}



import SwiftUI
import AuthenticationServices

struct AppleSignInButton: UIViewRepresentable {
  let onToken: (String) -> Void
  let onError: (Error?) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken, onError: onError) }

  func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
    let btn = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
    btn.cornerRadius = 12
    btn.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
    return btn
  }

  func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

  final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let onToken: (String) -> Void
    let onError: (Error?) -> Void
    init(onToken: @escaping (String) -> Void, onError: @escaping (Error?) -> Void) { self.onToken = onToken; self.onError = onError }

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
      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8) else {
        onError(nil); return
      }
      onToken(token)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
      onError(error)
    }
  }
}



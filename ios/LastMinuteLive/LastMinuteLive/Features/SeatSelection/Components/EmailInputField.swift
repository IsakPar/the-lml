import SwiftUI
import Combine

/// Clean, reusable email input component with validation
/// Follows LML design system with glassmorphism styling
struct EmailInputField: View {
    
    // MARK: - State Management
    @Binding var email: String
    @State private var validationResult: ValidationResult = .invalid("Email is required")
    @State private var isFieldFocused: Bool = false
    
    // MARK: - Configuration
    let placeholder: String
    let prefillEmail: String?
    let isRequired: Bool // New: Whether email is required (when not authenticated)
    
    // MARK: - Initialization
    init(email: Binding<String>, placeholder: String = "Enter email for receipt", prefillEmail: String? = nil, isRequired: Bool = false) {
        self._email = email
        self.placeholder = placeholder
        self.prefillEmail = prefillEmail
        self.isRequired = isRequired
    }
    
    // MARK: - Computed Properties
    private var isValid: Bool {
        validationResult.isValid
    }
    
    private var showError: Bool {
        if isRequired {
            // Show error if required and (empty or invalid)
            return !isFieldFocused && (email.isEmpty || !isValid)
        } else {
            // Show error only if not empty and invalid
            return !isFieldFocused && !email.isEmpty && !isValid
        }
    }
    
    private var showSuccess: Bool {
        !email.isEmpty && isValid
    }
    
    private var effectivePlaceholder: String {
        if isRequired {
            return placeholder + " *"
        }
        return placeholder
    }
    
    // MARK: - View Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Email input section header
            HStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Email for receipt")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                // Validation indicator
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(StageKit.success)
                        .transition(.scale)
                } else if showError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .transition(.scale)
                }
            }
            
            // Email text field with glassmorphism styling
            TextField(effectivePlaceholder, text: $email)
                .textFieldStyle(.plain)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled(true)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        // Glassmorphism background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                        
                        // Border color based on validation state
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 1.5)
                    }
                )
                .onTapGesture {
                    isFieldFocused = true
                }
                .onChange(of: email) { _, newValue in
                    validateEmail(newValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    isFieldFocused = false
                }
                .onAppear {
                    prefillEmailIfNeeded()
                }
            
            // Error message
            if showError, let errorMessage = validationResult.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showError)
        .animation(.easeInOut(duration: 0.2), value: showSuccess)
        .animation(.easeInOut(duration: 0.2), value: isFieldFocused)
    }
    
    // MARK: - Private Methods
    private var borderColor: Color {
        if isFieldFocused {
            return StageKit.brandEnd.opacity(0.6)
        } else if showError {
            return .red.opacity(0.6)
        } else if showSuccess {
            return StageKit.success.opacity(0.6)
        } else {
            return StageKit.hairline.opacity(0.4)
        }
    }
    
    private func validateEmail(_ emailText: String) {
        if isRequired && emailText.isEmpty {
            validationResult = .invalid("Email is required")
        } else {
            validationResult = EmailValidator.validate(emailText)
        }
    }
    
    private func prefillEmailIfNeeded() {
        if let prefillEmail = prefillEmail, email.isEmpty {
            email = prefillEmail
            validateEmail(prefillEmail)
        }
    }
}

// MARK: - Public Interface Extensions
extension EmailInputField {
    
    /// Check if the current email is valid for checkout
    var isValidForCheckout: Bool {
        EmailValidator.isValidForCheckout(email)
    }
    
    /// Get cleaned email for API submission
    var cleanedEmail: String {
        EmailValidator.clean(email)
    }
}

// MARK: - Preview
struct EmailInputField_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            StageKit.bgGradient.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Empty state
                EmailInputField(email: .constant(""))
                
                // Valid email state
                EmailInputField(email: .constant("[email protected]"))
                
                // Invalid email state
                EmailInputField(email: .constant("invalid-email"))
                
                // Pre-filled state
                EmailInputField(email: .constant(""), prefillEmail: "[email protected]")
            }
            .padding(20)
        }
    }
}

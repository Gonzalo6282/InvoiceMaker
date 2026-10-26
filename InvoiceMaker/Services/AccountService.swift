import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation
import Observation

/// Optional Sign in with Apple (via Firebase Auth). The Firebase user id
/// becomes the RevenueCat app user id, so Premium follows the user to a new
/// phone. Delete account revokes the Apple token and deletes the Firebase user.
@MainActor
@Observable
final class AccountService {
    static let shared = AccountService()

    private(set) var userID: String?
    private(set) var email: String?
    private var currentNonce: String?
    private var listener: AuthStateDidChangeListenerHandle?

    var isAvailable: Bool { AppAnalytics.shared.isConfigured }
    var isSignedIn: Bool { userID != nil }

    func start() {
        guard isAvailable, listener == nil else { return }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let id = user?.uid
            let mail = user?.email
            Task { @MainActor in
                self?.userID = id
                self?.email = mail
                if let id { await PurchaseManager.shared.logIn(userID: id) }
            }
        }
    }

    // MARK: Sign in with Apple

    /// Use in `SignInWithAppleButton(onRequest:)`.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
    }

    /// Use in `SignInWithAppleButton(onCompletion:)`. Throws on failure.
    func complete(_ result: Result<ASAuthorization, Error>) async throws {
        let authorization = try result.get()
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = apple.identityToken, let token = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else { throw AccountError.missingToken }
        let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: apple.fullName)
        _ = try await Auth.auth().signIn(with: credential)
    }

    func signOut() async {
        try? Auth.auth().signOut()
        await PurchaseManager.shared.logOut()
    }

    /// Deletes the account. Needs a fresh Apple sign-in (for the authorization
    /// code Apple requires to revoke the token). Local invoices stay on the device.
    func deleteAccount(with result: Result<ASAuthorization, Error>) async throws {
        let authorization = try result.get()
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
            let codeData = apple.authorizationCode, let code = String(data: codeData, encoding: .utf8),
            let tokenData = apple.identityToken, let token = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce, let user = Auth.auth().currentUser
        else { throw AccountError.missingToken }
        let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: nil)
        _ = try await user.reauthenticate(with: credential)
        try await Auth.auth().revokeToken(withAuthorizationCode: code)
        try await user.delete()
        await PurchaseManager.shared.logOut()
    }

    /// The message for the alert, or nil when the user cancelled Apple's sheet
    /// (nothing to show). The full error (domain, code, Firebase's server
    /// reason, underlying errors) is printed to the Xcode console as
    /// "[Duly account]"; debug builds also show it in the alert.
    static func report(_ error: Error, step: String) -> String? {
        let ns = error as NSError
        let detail = describe(ns)
        print("[Duly account] \(step) failed: \(detail)")
        let message: String
        switch (ns.domain, ns.code) {
        case (ASAuthorizationError.errorDomain, ASAuthorizationError.canceled.rawValue):
            return nil
        case (ASAuthorizationError.errorDomain, ASAuthorizationError.unknown.rawValue):
            // Error 1000 (often AKAuthenticationError -7071): Apple's link to Duly needs resetting.
            message = appleResetHelp
        default:
            message = error.localizedDescription
        }
        #if DEBUG
            return message + "\n\n" + detail
        #else
            return message
        #endif
    }

    static let appleResetHelp = String(
        localized: "Apple couldn't confirm it's you. On your iPhone, open Settings > [your name] > Sign-In & Security > Sign in with Apple > Duly and tap Stop Using Apple ID. Then come back to Duly and try again.")

    nonisolated static func describe(_ error: NSError, depth: Int = 0) -> String {
        var parts = ["\(error.domain) \(error.code)"]
        for (key, value) in error.userInfo where key != NSUnderlyingErrorKey {
            parts.append("\(key)=\(value)")
        }
        if depth < 3, let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying: " + describe(underlying, depth: depth + 1))
        }
        return parts.joined(separator: " | ")
    }

    enum AccountError: LocalizedError {
        case missingToken
        var errorDescription: String? { String(localized: "Sign in with Apple didn't finish. Please try again.") }
    }

    // MARK: Nonce (Firebase docs)

    nonisolated static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count, using: &generator)] })
    }

    nonisolated static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

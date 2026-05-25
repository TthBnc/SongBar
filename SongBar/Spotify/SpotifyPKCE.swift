import CryptoKit
import Foundation

enum SpotifyPKCE {
    private static let allowedCharacters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func makeCodeVerifier(length: Int = 64) -> String {
        precondition((43...128).contains(length), "PKCE verifier length must be between 43 and 128 characters.")
        return randomString(length: length)
    }

    static func makeState(length: Int = 32) -> String {
        randomString(length: length)
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func randomString(length: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).compactMap { _ in allowedCharacters.randomElement(using: &generator) })
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}


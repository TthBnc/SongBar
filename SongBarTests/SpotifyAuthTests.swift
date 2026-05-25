import XCTest
@testable import SongBar

final class SpotifyAuthTests: XCTestCase {
    func test_pkceChallengeMatchesRFC7636Example() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let challenge = SpotifyPKCE.codeChallenge(for: verifier)
        XCTAssertEqual(challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func test_authorizationURLContainsPKCEAndCallbackParameters() throws {
        let client = SpotifyAuthClient()
        let verifier = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        let request = try client.makeAuthorizationRequest(
            clientID: "abc123",
            state: "state-123",
            codeVerifier: verifier
        )

        let components = try XCTUnwrap(URLComponents(url: request.authorizationURL, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "accounts.spotify.com")
        XCTAssertEqual(components.path, "/authorize")
        XCTAssertEqual(queryItems.value(named: "response_type"), "code")
        XCTAssertEqual(queryItems.value(named: "client_id"), "abc123")
        XCTAssertEqual(queryItems.value(named: "redirect_uri"), "http://127.0.0.1:17654/callback")
        XCTAssertEqual(queryItems.value(named: "scope"), "user-library-read user-library-modify")
        XCTAssertEqual(queryItems.value(named: "state"), "state-123")
        XCTAssertEqual(queryItems.value(named: "code_challenge_method"), "S256")
        XCTAssertEqual(queryItems.value(named: "code_challenge"), SpotifyPKCE.codeChallenge(for: verifier))
    }

    func test_authorizationURLRejectsBlankClientID() {
        let client = SpotifyAuthClient()
        XCTAssertThrowsError(
            try client.makeAuthorizationRequest(clientID: "  ", state: "state", codeVerifier: SpotifyPKCE.makeCodeVerifier())
        )
    }

    func test_callbackTargetParsesNormalCallbackPath() throws {
        let components = try XCTUnwrap(SpotifyOAuthCallbackTarget.components(from: "/callback?code=abc&state=state-123"))
        XCTAssertEqual(components.host, "127.0.0.1")
        XCTAssertEqual(components.path, "/callback")
        XCTAssertEqual(components.queryItems?.value(named: "code"), "abc")
        XCTAssertEqual(components.queryItems?.value(named: "state"), "state-123")
    }

    func test_callbackTargetParsesAbsoluteCallbackURL() throws {
        let components = try XCTUnwrap(SpotifyOAuthCallbackTarget.components(from: "http://127.0.0.1:17654/callback?code=abc"))
        XCTAssertEqual(components.host, "127.0.0.1")
        XCTAssertEqual(components.port, 17_654)
        XCTAssertEqual(components.path, "/callback")
        XCTAssertEqual(components.queryItems?.value(named: "code"), "abc")
    }

    func test_callbackTargetRepairsBrowserPathWithEmbeddedLoopbackHost() throws {
        let components = try XCTUnwrap(SpotifyOAuthCallbackTarget.components(from: "/127.0.0.1:17654/callback?code=abc"))
        XCTAssertEqual(components.host, "127.0.0.1")
        XCTAssertEqual(components.path, "/callback")
        XCTAssertEqual(components.queryItems?.value(named: "code"), "abc")
    }

    func test_callbackTargetRepairsAbsoluteBrowserPathWithEmbeddedLoopbackHost() throws {
        let components = try XCTUnwrap(
            SpotifyOAuthCallbackTarget.components(from: "http://127.0.0.1/127.0.0.1:17654/callback?code=abc")
        )
        XCTAssertEqual(components.host, "127.0.0.1")
        XCTAssertEqual(components.path, "/callback")
        XCTAssertEqual(components.queryItems?.value(named: "code"), "abc")
    }
}

private extension Array where Element == URLQueryItem {
    func value(named name: String) -> String? {
        first { $0.name == name }?.value
    }
}

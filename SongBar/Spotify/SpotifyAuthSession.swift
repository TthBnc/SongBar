import Foundation

struct SpotifyAuthSession: Codable, Equatable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let refreshToken: String?
    let expiresAt: Date

    var isExpiredSoon: Bool {
        expiresAt <= Date().addingTimeInterval(60)
    }
}


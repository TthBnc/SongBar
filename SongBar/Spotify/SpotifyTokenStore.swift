import Foundation
import Security

struct SpotifyTokenStore {
    private let service = "dev.tothbnc.SongBar.spotify"
    private let account = "session"

    func load() throws -> SpotifyAuthSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw SpotifyAuthError.keychainFailed(status)
        }

        guard let data = result as? Data else {
            return nil
        }

        return try JSONDecoder().decode(SpotifyAuthSession.self, from: data)
    }

    func save(_ session: SpotifyAuthSession) throws {
        let data = try JSONEncoder().encode(session)
        var query = baseQuery()
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                baseQuery() as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw SpotifyAuthError.keychainFailed(updateStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw SpotifyAuthError.keychainFailed(status)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SpotifyAuthError.keychainFailed(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}


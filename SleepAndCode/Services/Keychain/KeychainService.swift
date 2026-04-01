import Foundation
import Security

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status): return "Keychain save failed: \(status)"
        case .readFailed(let status): return "Keychain read failed: \(status)"
        case .deleteFailed(let status): return "Keychain delete failed: \(status)"
        case .unexpectedData: return "Unexpected keychain data"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = Constants.Keychain.service

    private init() {}

    func save(_ value: String, for key: String) throws {
        let data = Data(value.utf8)

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Convenience

    var githubPAT: String? {
        get { read(Constants.Keychain.githubPATKey) }
        set {
            if let newValue {
                try? save(newValue, for: Constants.Keychain.githubPATKey)
            } else {
                delete(Constants.Keychain.githubPATKey)
            }
        }
    }

    var githubUsername: String? {
        get { read(Constants.Keychain.githubUsernameKey) }
        set {
            if let newValue {
                try? save(newValue, for: Constants.Keychain.githubUsernameKey)
            } else {
                delete(Constants.Keychain.githubUsernameKey)
            }
        }
    }

    var ouraAccessToken: String? {
        get { read(Constants.Keychain.ouraAccessTokenKey) }
        set {
            if let newValue {
                try? save(newValue, for: Constants.Keychain.ouraAccessTokenKey)
            } else {
                delete(Constants.Keychain.ouraAccessTokenKey)
            }
        }
    }

    var ouraRefreshToken: String? {
        get { read(Constants.Keychain.ouraRefreshTokenKey) }
        set {
            if let newValue {
                try? save(newValue, for: Constants.Keychain.ouraRefreshTokenKey)
            } else {
                delete(Constants.Keychain.ouraRefreshTokenKey)
            }
        }
    }

    var ouraTokenExpiry: Date? {
        get {
            guard let string = read(Constants.Keychain.ouraTokenExpiryKey),
                  let interval = TimeInterval(string) else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let newValue {
                try? save(String(newValue.timeIntervalSince1970), for: Constants.Keychain.ouraTokenExpiryKey)
            } else {
                delete(Constants.Keychain.ouraTokenExpiryKey)
            }
        }
    }

    var isGitHubConnected: Bool {
        githubPAT != nil
    }

    var isOuraConnected: Bool {
        ouraAccessToken != nil
    }

    func disconnectGitHub() {
        delete(Constants.Keychain.githubPATKey)
        delete(Constants.Keychain.githubUsernameKey)
    }

    func disconnectOura() {
        delete(Constants.Keychain.ouraAccessTokenKey)
        delete(Constants.Keychain.ouraRefreshTokenKey)
        delete(Constants.Keychain.ouraTokenExpiryKey)
    }
}

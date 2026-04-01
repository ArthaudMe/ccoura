import AuthenticationServices
import Foundation

struct OuraTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}

@MainActor
final class OuraAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OuraAuthService()

    private let keychain = KeychainService.shared

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }

    func authenticate() async throws {
        try await startOAuthFlow()
    }

    func startOAuthFlow() async throws {
        let code = try await getAuthorizationCode()
        let tokens = try await exchangeCodeForTokens(code)
        persistTokens(tokens)
    }

    private func getAuthorizationCode() async throws -> String {
        var components = URLComponents(string: Constants.Oura.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.Oura.clientID),
            URLQueryItem(name: "redirect_uri", value: Constants.Oura.callbackURL),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "daily"),
            URLQueryItem(name: "state", value: UUID().uuidString),
        ]

        let url = components.url!

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Constants.Oura.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: OuraError.noAuthorizationCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchangeCodeForTokens(_ code: String) async throws -> OuraTokenResponse {
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": Constants.Oura.clientID,
            "client_secret": Constants.Oura.clientSecret,
            "redirect_uri": Constants.Oura.callbackURL,
        ]

        let bodyString = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")

        let (data, response) = try await NetworkClient.shared.requestRaw(
            url: Constants.Oura.tokenURL,
            method: "POST",
            body: Data(bodyString.utf8)
        )

        guard response.statusCode == 200 else {
            throw OuraError.tokenExchangeFailed(response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(OuraTokenResponse.self, from: data)
    }

    func refreshAccessToken() async throws {
        guard let refreshToken = keychain.ouraRefreshToken else {
            throw OuraError.noRefreshToken
        }

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Constants.Oura.clientID,
            "client_secret": Constants.Oura.clientSecret,
        ]

        let bodyString = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")

        let (data, response) = try await NetworkClient.shared.requestRaw(
            url: Constants.Oura.tokenURL,
            method: "POST",
            body: Data(bodyString.utf8)
        )

        guard response.statusCode == 200 else {
            // Refresh token might be consumed — disconnect
            keychain.disconnectOura()
            throw OuraError.refreshFailed(response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tokens = try decoder.decode(OuraTokenResponse.self, from: data)

        // CRITICAL: persist new refresh token BEFORE using access token
        persistTokens(tokens)
    }

    private func persistTokens(_ tokens: OuraTokenResponse) {
        // Persist refresh token first (single-use, most critical)
        keychain.ouraRefreshToken = tokens.refreshToken
        keychain.ouraAccessToken = tokens.accessToken
        keychain.ouraTokenExpiry = Date.now.addingTimeInterval(TimeInterval(tokens.expiresIn))
    }

    func ensureValidToken() async throws {
        guard keychain.isOuraConnected else {
            throw OuraError.notConnected
        }

        if let expiry = keychain.ouraTokenExpiry, expiry < .now.addingTimeInterval(300) {
            try await refreshAccessToken()
        }
    }
}

enum OuraError: LocalizedError {
    case noAuthorizationCode
    case tokenExchangeFailed(Int)
    case noRefreshToken
    case refreshFailed(Int)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .noAuthorizationCode: return "No authorization code received"
        case .tokenExchangeFailed(let code): return "Token exchange failed (HTTP \(code))"
        case .noRefreshToken: return "No refresh token — please reconnect Oura"
        case .refreshFailed(let code): return "Token refresh failed (HTTP \(code))"
        case .notConnected: return "Oura not connected"
        }
    }
}

import Foundation

// MARK: - API Response Models

struct OuraDailySleepResponse: Decodable {
    let data: [OuraDailySleep]
    let nextToken: String?
}

struct OuraDailySleep: Decodable {
    let day: String
    let score: Int?
    let contributors: OuraSleepContributors?
    let hrLowest: Double?
    let averageHrv: Double?
    let bedtimeStart: String?
    let bedtimeEnd: String?
}

struct OuraSleepContributors: Decodable {
    let totalSleep: Int?
    let remSleep: Int?
    let deepSleep: Int?
    let efficiency: Int?
}

// MARK: - API Client

actor OuraAPIClient {
    private let network = NetworkClient.shared
    private let keychain = KeychainService.shared

    init() {}

    // MARK: - Authorization

    private func ensureValidToken() async throws {
        guard keychain.isOuraConnected else {
            throw OuraError.notConnected
        }
        if let expiry = keychain.ouraTokenExpiry, expiry < .now.addingTimeInterval(300) {
            try await OuraAuthService.shared.refreshAccessToken()
        }
    }

    private func authHeaders() async throws -> [String: String] {
        try await ensureValidToken()

        guard let token = keychain.ouraAccessToken else {
            throw OuraError.notConnected
        }
        return ["Authorization": "Bearer \(token)"]
    }

    // MARK: - Daily Sleep

    func fetchDailySleep(
        startDate: String,
        endDate: String
    ) async throws -> [OuraDailySleep] {
        var allSleep: [OuraDailySleep] = []
        var nextToken: String? = nil

        repeat {
            var queryItems = [
                URLQueryItem(name: "start_date", value: startDate),
                URLQueryItem(name: "end_date", value: endDate),
            ]

            if let nextToken {
                queryItems.append(URLQueryItem(name: "next_token", value: nextToken))
            }

            let headers = try await authHeaders()

            let response: OuraDailySleepResponse = try await network.request(
                url: "\(Constants.Oura.apiBase)/v2/usercollection/daily_sleep",
                headers: headers,
                queryItems: queryItems
            )

            allSleep.append(contentsOf: response.data)
            nextToken = response.nextToken
        } while nextToken != nil

        return allSleep
    }
}

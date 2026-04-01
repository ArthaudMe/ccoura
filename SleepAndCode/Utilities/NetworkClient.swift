import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, body: String?)
    case decodingError(Error)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case noData
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .httpError(let code, _): return "HTTP error \(code)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .unauthorized: return "Unauthorized — check your credentials"
        case .rateLimited: return "Rate limited — try again later"
        case .noData: return "No data received"
        case .unknown(let error): return error.localizedDescription
        }
    }
}

actor NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        guard var components = URLComponents(string: url) else {
            throw NetworkError.invalidURL
        }

        if let queryItems {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }

        guard let requestURL = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await performWithRetry(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        case 401:
            throw NetworkError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        default:
            let body = String(data: data, encoding: .utf8)
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }

    func requestRaw(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(string: url) else {
            throw NetworkError.invalidURL
        }

        if let queryItems {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }

        guard let requestURL = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await performWithRetry(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        return (data, httpResponse)
    }

    private func performWithRetry(
        request: URLRequest,
        maxRetries: Int = 2
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = pow(2.0, Double(attempt - 1))
                try await Task.sleep(for: .seconds(delay))
            }
            do {
                return try await session.data(for: request)
            } catch {
                lastError = error
                if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                    throw NetworkError.unknown(error)
                }
            }
        }
        throw NetworkError.unknown(lastError ?? URLError(.unknown))
    }
}

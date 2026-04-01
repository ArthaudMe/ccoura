import Foundation

// MARK: - API Response Models

struct GitHubUser: Decodable {
    let login: String
    let id: Int
    let avatarUrl: String?
}

struct GitHubRepo: Decodable, Identifiable {
    let id: Int
    let fullName: String
    let name: String
    let owner: GitHubRepoOwner
    let description: String?
    let isPrivate: Bool
    let pushedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, fullName, name, owner, description
        case isPrivate = "private"
        case pushedAt
    }
}

struct GitHubRepoOwner: Decodable {
    let login: String
    let avatarUrl: String?
}

struct GitHubCommit: Decodable {
    let sha: String
    let commit: GitHubCommitDetail
    let author: GitHubCommitAuthor?
}

struct GitHubCommitDetail: Decodable {
    let message: String
    let author: GitHubCommitPerson?
}

struct GitHubCommitPerson: Decodable {
    let name: String?
    let date: String?
}

struct GitHubCommitAuthor: Decodable {
    let login: String?
}

struct GitHubCommitStats: Decodable {
    let sha: String
    let stats: GitHubStats?
}

struct GitHubStats: Decodable {
    let additions: Int
    let deletions: Int
    let total: Int
}

// MARK: - API Client

actor GitHubAPIClient {
    private let network = NetworkClient.shared
    private let keychain = KeychainService.shared

    private var authHeaders: [String: String] {
        guard let pat = keychain.githubPAT else { return [:] }
        return [
            "Authorization": "Bearer \(pat)",
            "X-GitHub-Api-Version": "2022-11-28",
        ]
    }

    func validateToken(_ pat: String) async throws -> GitHubUser {
        let headers = [
            "Authorization": "Bearer \(pat)",
            "X-GitHub-Api-Version": "2022-11-28",
        ]
        return try await network.request(
            url: "\(Constants.GitHub.apiBase)/user",
            headers: headers
        )
    }

    func fetchRepos(page: Int = 1) async throws -> [GitHubRepo] {
        try await network.request(
            url: "\(Constants.GitHub.apiBase)/user/repos",
            headers: authHeaders,
            queryItems: [
                URLQueryItem(name: "per_page", value: "\(Constants.GitHub.perPage)"),
                URLQueryItem(name: "sort", value: "pushed"),
                URLQueryItem(name: "direction", value: "desc"),
                URLQueryItem(name: "page", value: "\(page)"),
            ]
        )
    }

    func fetchAllRepos() async throws -> [GitHubRepo] {
        var allRepos: [GitHubRepo] = []
        var page = 1
        while true {
            let repos: [GitHubRepo] = try await fetchRepos(page: page)
            allRepos.append(contentsOf: repos)
            if repos.count < Constants.GitHub.perPage { break }
            page += 1
        }
        return allRepos
    }

    func fetchCommits(
        repo: String,
        author: String,
        since: Date? = nil,
        page: Int = 1
    ) async throws -> [GitHubCommit] {
        var queryItems = [
            URLQueryItem(name: "per_page", value: "\(Constants.GitHub.perPage)"),
            URLQueryItem(name: "author", value: author),
            URLQueryItem(name: "page", value: "\(page)"),
        ]

        if let since {
            queryItems.append(URLQueryItem(name: "since", value: DateHelpers.iso8601String(from: since)))
        }

        return try await network.request(
            url: "\(Constants.GitHub.apiBase)/repos/\(repo)/commits",
            headers: authHeaders,
            queryItems: queryItems
        )
    }

    func fetchAllCommits(
        repo: String,
        author: String,
        since: Date? = nil
    ) async throws -> [GitHubCommit] {
        var allCommits: [GitHubCommit] = []
        var page = 1
        while true {
            let commits = try await fetchCommits(repo: repo, author: author, since: since, page: page)
            allCommits.append(contentsOf: commits)
            if commits.count < Constants.GitHub.perPage { break }
            page += 1
        }
        return allCommits
    }

    func fetchCommitDetail(repo: String, sha: String) async throws -> GitHubCommitStats {
        try await network.request(
            url: "\(Constants.GitHub.apiBase)/repos/\(repo)/commits/\(sha)",
            headers: authHeaders
        )
    }
}

import Foundation

enum Constants {
    enum GitHub {
        static let apiBase = "https://api.github.com"
        static let perPage = 100
        static let maxCommitStatsPerSync = 50
        static let backfillDays = 90
    }

    enum Oura {
        static let apiBase = "https://api.ouraring.com"
        static let authorizeURL = "https://cloud.ouraring.com/oauth/authorize"
        static let tokenURL = "https://api.ouraring.com/oauth/token"
        static let callbackScheme = "sleepandcode"
        static let callbackURL = "sleepandcode://oura-callback"
        static let backfillDays = 90
        // Replace with your own Oura app credentials
        static let clientID = "OURA_CLIENT_ID"
        static let clientSecret = "OURA_CLIENT_SECRET"
    }

    enum Sync {
        static let backgroundTaskID = "com.sleepandcode.sync"
        static let minimumForegroundSyncInterval: TimeInterval = 2 * 3600 // 2 hours
        static let backgroundRefreshInterval: TimeInterval = 4 * 3600 // 4 hours
    }

    enum Data {
        static let retentionDays = 365
        static let minimumInsightDays = 14
    }

    enum Keychain {
        static let service = "com.sleepandcode"
        static let githubPATKey = "github_pat"
        static let githubUsernameKey = "github_username"
        static let ouraAccessTokenKey = "oura_access_token"
        static let ouraRefreshTokenKey = "oura_refresh_token"
        static let ouraTokenExpiryKey = "oura_token_expiry"
    }
}

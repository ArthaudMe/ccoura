import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var isGitHubConnected = false
    var isOuraConnected = false
    var githubUsername: String?
    var repos: [GitHubRepo] = []
    var trackedRepos: [TrackedRepository] = []
    var isLoadingRepos = false
    var isValidatingPAT = false
    var patError: String?
    var ouraError: String?
    var githubSyncState: SyncState?
    var ouraSyncState: SyncState?

    private let keychain = KeychainService.shared

    func loadState(modelContext: ModelContext) {
        isGitHubConnected = keychain.isGitHubConnected
        isOuraConnected = keychain.isOuraConnected
        githubUsername = keychain.githubUsername

        let repoDescriptor = FetchDescriptor<TrackedRepository>(
            sortBy: [SortDescriptor(\.fullName)]
        )
        trackedRepos = (try? modelContext.fetch(repoDescriptor)) ?? []

        // Load sync states
        let ghSource = SyncSource.github.rawValue
        let ghPredicate = #Predicate<SyncState> { $0.source == ghSource }
        githubSyncState = try? modelContext.fetch(FetchDescriptor<SyncState>(predicate: ghPredicate)).first

        let ouraSource = SyncSource.oura.rawValue
        let ouraPredicate = #Predicate<SyncState> { $0.source == ouraSource }
        ouraSyncState = try? modelContext.fetch(FetchDescriptor<SyncState>(predicate: ouraPredicate)).first
    }

    func validateAndSaveGitHubPAT(_ pat: String) async throws {
        isValidatingPAT = true
        patError = nil
        defer { isValidatingPAT = false }

        let trimmed = pat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            patError = "Please enter a token"
            return
        }

        let api = GitHubAPIClient()
        do {
            let user = try await api.validateToken(trimmed)
            keychain.githubPAT = trimmed
            keychain.githubUsername = user.login
            githubUsername = user.login
            isGitHubConnected = true
        } catch NetworkError.unauthorized {
            patError = "Invalid token. Check permissions and try again."
            throw NetworkError.unauthorized
        } catch {
            patError = error.localizedDescription
            throw error
        }
    }

    func loadGitHubRepos() async {
        isLoadingRepos = true
        defer { isLoadingRepos = false }

        let api = GitHubAPIClient()
        do {
            repos = try await api.fetchAllRepos()
        } catch {
            patError = "Failed to load repos: \(error.localizedDescription)"
        }
    }

    func toggleRepo(_ repo: GitHubRepo, modelContext: ModelContext) {
        let name = repo.fullName
        if let existing = trackedRepos.first(where: { $0.fullName == name }) {
            existing.isActive.toggle()
        } else {
            let tracked = TrackedRepository(
                fullName: repo.fullName,
                ownerAvatarURL: repo.owner.avatarUrl,
                repoDescription: repo.description,
                isPrivate: repo.isPrivate
            )
            modelContext.insert(tracked)
            trackedRepos.append(tracked)
        }
        try? modelContext.save()
    }

    func isRepoTracked(_ repo: GitHubRepo) -> Bool {
        trackedRepos.first(where: { $0.fullName == repo.fullName })?.isActive ?? false
    }

    func disconnectGitHub(modelContext: ModelContext) {
        keychain.disconnectGitHub()
        isGitHubConnected = false
        githubUsername = nil

        // Remove all tracked repos and commits
        try? modelContext.delete(model: TrackedRepository.self)
        try? modelContext.delete(model: CommitRecord.self)
        try? modelContext.delete(model: DailyAggregate.self)
        trackedRepos = []
        try? modelContext.save()
    }

    func disconnectOura(modelContext: ModelContext) {
        keychain.disconnectOura()
        isOuraConnected = false

        try? modelContext.delete(model: SleepRecord.self)
        try? modelContext.save()
    }

    func exportCSV(modelContext: ModelContext) -> URL? {
        let sleepRecords = (try? modelContext.fetch(FetchDescriptor<SleepRecord>(
            sortBy: [SortDescriptor(\.dayKey)]
        ))) ?? []
        let aggregates = (try? modelContext.fetch(FetchDescriptor<DailyAggregate>(
            sortBy: [SortDescriptor(\.dayKey)]
        ))) ?? []

        let aggByDay = Dictionary(uniqueKeysWithValues: aggregates.map { ($0.dayKey, $0) })

        var csv = "date,sleep_score,total_sleep_hours,deep_sleep_min,rem_sleep_min,efficiency,hrv,commits,additions,deletions,active_hours,quality_score\n"

        let allDays = Set(sleepRecords.map(\.dayKey)).union(aggregates.map(\.dayKey)).sorted()

        for day in allDays {
            let sleep = sleepRecords.first { $0.dayKey == day }
            let agg = aggByDay[day]
            let row = [
                day,
                sleep.map { "\($0.score)" } ?? "",
                sleep.map { String(format: "%.1f", $0.totalSleepHours) } ?? "",
                sleep.map { "\($0.deepSleepSeconds / 60)" } ?? "",
                sleep.map { "\($0.remSleepSeconds / 60)" } ?? "",
                sleep.map { "\($0.efficiency)" } ?? "",
                sleep?.hrv.map { String(format: "%.0f", $0) } ?? "",
                agg.map { "\($0.commitCount)" } ?? "0",
                agg.map { "\($0.totalAdditions)" } ?? "0",
                agg.map { "\($0.totalDeletions)" } ?? "0",
                agg.map { "\($0.activeHoursCount)" } ?? "0",
                agg.map { String(format: "%.1f", $0.qualityScore) } ?? "0",
            ].joined(separator: ",")
            csv += row + "\n"
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sleep_and_code_export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}

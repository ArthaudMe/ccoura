import Foundation
import SwiftData

@ModelActor
actor GitHubSyncService {
    private var api: GitHubAPIClient { GitHubAPIClient() }

    func syncAllRepos() async throws {
        guard let username = KeychainService.shared.githubUsername else { return }

        let descriptor = FetchDescriptor<TrackedRepository>(
            predicate: #Predicate { $0.isActive }
        )
        let repos = try modelContext.fetch(descriptor)

        for repo in repos {
            try await syncRepo(repo, username: username)
        }

        try recomputeAggregates()
        try pruneOldData()
    }

    private func syncRepo(
        _ repo: TrackedRepository,
        username: String
    ) async throws {
        let since = repo.lastSyncedAt ?? DateHelpers.daysAgo(Constants.GitHub.backfillDays)

        let commits = try await api.fetchAllCommits(
            repo: repo.fullName,
            author: username,
            since: since
        )

        for ghCommit in commits {
            let sha = ghCommit.sha
            let existing = FetchDescriptor<CommitRecord>(
                predicate: #Predicate<CommitRecord> { $0.sha == sha }
            )
            if (try? modelContext.fetchCount(existing)) ?? 0 > 0 {
                continue
            }

            guard let dateString = ghCommit.commit.author?.date,
                  let authorDate = DateHelpers.parseISO8601(dateString) else {
                continue
            }

            let record = CommitRecord(
                sha: ghCommit.sha,
                repoFullName: repo.fullName,
                authorDate: authorDate,
                message: String(ghCommit.commit.message.prefix(200))
            )
            modelContext.insert(record)
        }

        // Enrich commits without detailed stats (batch limited)
        try await enrichCommitStats(repo: repo.fullName)

        repo.lastSyncedAt = .now
        try modelContext.save()
    }

    private func enrichCommitStats(repo: String) async throws {
        let repoName = repo
        var descriptor = FetchDescriptor<CommitRecord>(
            predicate: #Predicate<CommitRecord> {
                $0.repoFullName == repoName && !$0.hasDetailedStats
            },
            sortBy: [SortDescriptor(\.authorDate, order: .reverse)]
        )
        descriptor.fetchLimit = Constants.GitHub.maxCommitStatsPerSync

        let commits = try modelContext.fetch(descriptor)

        for commit in commits {
            do {
                let detail = try await api.fetchCommitDetail(repo: repo, sha: commit.sha)
                commit.additions = detail.stats?.additions ?? 0
                commit.deletions = detail.stats?.deletions ?? 0
                commit.hasDetailedStats = true
            } catch NetworkError.rateLimited {
                break
            } catch {
                continue
            }
        }

        try modelContext.save()
    }

    func recomputeAggregates() throws {
        let allCommits = try modelContext.fetch(FetchDescriptor<CommitRecord>())

        var grouped: [String: [CommitRecord]] = [:]
        for commit in allCommits {
            grouped[commit.dayKey, default: []].append(commit)
        }

        for (dayKey, commits) in grouped {
            let dk = dayKey
            let predicate = #Predicate<DailyAggregate> { $0.dayKey == dk }
            let existing = try modelContext.fetch(FetchDescriptor<DailyAggregate>(predicate: predicate))
            let aggregate = existing.first ?? DailyAggregate(dayKey: dayKey, commitCount: 0)

            if existing.isEmpty {
                modelContext.insert(aggregate)
            }

            aggregate.commitCount = commits.count
            aggregate.totalAdditions = commits.reduce(0) { $0 + $1.additions }
            aggregate.totalDeletions = commits.reduce(0) { $0 + $1.deletions }

            let distinctHours = Set(commits.map { $0.hourOfDay })
            aggregate.activeHoursCount = distinctHours.count

            let totalChanges = commits.reduce(0) { $0 + $1.totalChanges }
            aggregate.avgCommitSize = commits.isEmpty ? 0 : Double(totalChanges) / Double(commits.count)

            aggregate.qualityScore = DailyAggregate.computeQualityScore(
                commitCount: aggregate.commitCount,
                totalChanges: aggregate.totalAdditions + aggregate.totalDeletions,
                activeHours: aggregate.activeHoursCount,
                avgCommitSize: aggregate.avgCommitSize
            )
        }

        try modelContext.save()
    }

    private func pruneOldData() throws {
        let cutoff = DateHelpers.dayKeyDaysAgo(Constants.Data.retentionDays)
        let commitPredicate = #Predicate<CommitRecord> { $0.dayKey < cutoff }
        try modelContext.delete(model: CommitRecord.self, where: commitPredicate)

        let aggPredicate = #Predicate<DailyAggregate> { $0.dayKey < cutoff }
        try modelContext.delete(model: DailyAggregate.self, where: aggPredicate)

        try modelContext.save()
    }
}

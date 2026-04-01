import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.sleepandcode", category: "SyncCoordinator")

@MainActor
@Observable
final class SyncCoordinator {
    static let shared = SyncCoordinator()

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?

    private init() {}

    // MARK: - Public API

    /// Syncs all data sources concurrently. One source failing does not prevent the other.
    func syncAll(modelContainer: ModelContainer) async {
        guard !isSyncing else {
            logger.info("Sync already in progress — skipping")
            return
        }

        isSyncing = true
        syncError = nil

        let githubService = GitHubSyncService(modelContainer: modelContainer)
        let ouraService = OuraSyncService(modelContainer: modelContainer)

        await updateSyncState(
            source: .github,
            status: .syncing,
            modelContainer: modelContainer
        )
        await updateSyncState(
            source: .oura,
            status: .syncing,
            modelContainer: modelContainer
        )

        async let githubResult: Result<Void, Error> = Self.runSync {
            try await githubService.syncAllRepos()
        }
        async let ouraResult: Result<Void, Error> = Self.runSync {
            try await ouraService.syncSleepData()
        }

        let results = await (github: githubResult, oura: ouraResult)

        var errors: [String] = []

        switch results.github {
        case .success:
            logger.info("GitHub sync completed successfully")
            await updateSyncState(
                source: .github,
                status: .success,
                modelContainer: modelContainer
            )
        case .failure(let error):
            logger.error("GitHub sync failed: \(error.localizedDescription)")
            errors.append("GitHub: \(error.localizedDescription)")
            await updateSyncState(
                source: .github,
                status: .failed,
                error: error.localizedDescription,
                modelContainer: modelContainer
            )
        }

        switch results.oura {
        case .success:
            logger.info("Oura sync completed successfully")
            await updateSyncState(
                source: .oura,
                status: .success,
                modelContainer: modelContainer
            )
        case .failure(let error):
            logger.error("Oura sync failed: \(error.localizedDescription)")
            errors.append("Oura: \(error.localizedDescription)")
            await updateSyncState(
                source: .oura,
                status: .failed,
                error: error.localizedDescription,
                modelContainer: modelContainer
            )
        }

        lastSyncDate = .now
        syncError = errors.isEmpty ? nil : errors.joined(separator: "; ")
        isSyncing = false

        logger.info("Sync cycle complete — errors: \(errors.count)")
    }

    /// Only syncs if the last successful sync was more than the minimum interval ago.
    func syncIfNeeded(modelContainer: ModelContainer) async {
        if let lastSync = lastSyncDate,
           Date.now.timeIntervalSince(lastSync) < Constants.Sync.minimumForegroundSyncInterval {
            logger.debug("Skipping sync — last sync was recent")
            return
        }

        // Also check persisted sync dates in case the app was relaunched
        let lastPersisted = await mostRecentSyncDate(modelContainer: modelContainer)
        if let lastPersisted,
           Date.now.timeIntervalSince(lastPersisted) < Constants.Sync.minimumForegroundSyncInterval {
            logger.debug("Skipping sync — persisted sync date is recent")
            lastSyncDate = lastPersisted
            return
        }

        await syncAll(modelContainer: modelContainer)
    }

    // MARK: - Private Helpers

    /// Wraps a throwing async closure into a non-throwing `Result` so that
    /// concurrent `async let` bindings don't propagate cancellation across siblings.
    private static func runSync(_ work: @Sendable () async throws -> Void) async -> Result<Void, Error> {
        do {
            try await work()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Fetches or creates a `SyncState` for the given source and updates it.
    private func updateSyncState(
        source: SyncSource,
        status: SyncStatus,
        error: String? = nil,
        modelContainer: ModelContainer
    ) async {
        let context = ModelContext(modelContainer)
        let sourceRaw = source.rawValue

        let descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.source == sourceRaw }
        )

        let state: SyncState
        if let existing = try? context.fetch(descriptor).first {
            state = existing
        } else {
            state = SyncState(source: source)
            context.insert(state)
        }

        state.status = status
        state.lastError = error

        if status == .success {
            state.lastSyncDate = .now
        }

        do {
            try context.save()
        } catch {
            logger.error("Failed to persist SyncState: \(error.localizedDescription)")
        }
    }

    /// Returns the most recent `lastSyncDate` across all sync sources.
    private func mostRecentSyncDate(modelContainer: ModelContainer) async -> Date? {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<SyncState>(
            sortBy: [SortDescriptor(\.lastSyncDate, order: .reverse)]
        )

        guard let states = try? context.fetch(descriptor) else { return nil }
        return states.compactMap(\.lastSyncDate).first
    }
}

import Foundation
import OSLog
import SwiftData

@ModelActor
actor OuraSyncService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SleepAndCode",
        category: "OuraSyncService"
    )

    private var api: OuraAPIClient {
        OuraAPIClient()
    }

    // MARK: - Public API

    /// Performs an incremental sync of Oura sleep data.
    /// On first sync, backfills the configured number of days.
    /// On subsequent syncs, fetches only data since the last successful sync.
    func syncSleepData() async throws {
        try await sync()
    }

    private func sync() async throws {
        let syncState = try getOrCreateSyncState()
        syncState.status = .syncing
        try modelContext.save()

        do {
            let recordCount = try await fetchAndUpsertSleep(lastSync: syncState.lastSyncDate)
            try pruneOldData()

            syncState.status = .success
            syncState.lastSyncDate = .now
            syncState.lastError = nil
            syncState.totalRecordsSynced += recordCount
            try modelContext.save()

            Self.logger.info("Oura sync completed: \(recordCount) records upserted")
        } catch {
            syncState.status = .failed
            syncState.lastError = error.localizedDescription
            try? modelContext.save()

            Self.logger.error("Oura sync failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Core Sync Logic

    private func fetchAndUpsertSleep(lastSync: Date?) async throws -> Int {
        let startDate: String
        if let lastSync {
            // Overlap by 1 day to catch late-arriving data
            let since = Calendar.current.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
            startDate = DateHelpers.dayKey(from: since)
        } else {
            startDate = DateHelpers.dayKeyDaysAgo(Constants.Oura.backfillDays)
        }

        let endDate = DateHelpers.today()

        let sleepEntries = try await api.fetchDailySleep(
            startDate: startDate,
            endDate: endDate
        )

        var upsertCount = 0
        for entry in sleepEntries {
            try upsertSleepRecord(from: entry)
            upsertCount += 1
        }

        try modelContext.save()
        return upsertCount
    }

    private func upsertSleepRecord(from entry: OuraDailySleep) throws {
        let day = entry.day
        let predicate = #Predicate<SleepRecord> { $0.dayKey == day }
        let descriptor = FetchDescriptor<SleepRecord>(predicate: predicate)
        let existing = try modelContext.fetch(descriptor)

        let record = existing.first ?? SleepRecord(
            dayKey: entry.day,
            score: 0,
            totalSleepSeconds: 0
        )

        if existing.isEmpty {
            modelContext.insert(record)
        }

        record.score = entry.score ?? 0
        record.totalSleepSeconds = entry.contributors?.totalSleep ?? 0
        record.remSleepSeconds = entry.contributors?.remSleep ?? 0
        record.deepSleepSeconds = entry.contributors?.deepSleep ?? 0
        record.lightSleepSeconds = max(
            0,
            (entry.contributors?.totalSleep ?? 0)
                - (entry.contributors?.remSleep ?? 0)
                - (entry.contributors?.deepSleep ?? 0)
        )
        record.efficiency = entry.contributors?.efficiency ?? 0
        record.restingHeartRate = entry.hrLowest
        record.hrv = entry.averageHrv

        if let start = entry.bedtimeStart {
            record.bedtimeStart = DateHelpers.parseISO8601(start)
        }
        if let end = entry.bedtimeEnd {
            record.bedtimeEnd = DateHelpers.parseISO8601(end)
        }
    }

    // MARK: - Pruning

    private func pruneOldData() throws {
        let cutoff = DateHelpers.dayKeyDaysAgo(Constants.Data.retentionDays)
        let predicate = #Predicate<SleepRecord> { $0.dayKey < cutoff }
        try modelContext.delete(model: SleepRecord.self, where: predicate)
        try modelContext.save()
    }

    // MARK: - Sync State

    private func getOrCreateSyncState() throws -> SyncState {
        let source = SyncSource.oura.rawValue
        let predicate = #Predicate<SyncState> { $0.source == source }
        let descriptor = FetchDescriptor<SyncState>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)

        if let existing = results.first {
            return existing
        }

        let state = SyncState(source: .oura)
        modelContext.insert(state)
        try modelContext.save()
        return state
    }
}

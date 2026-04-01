import Foundation
import SwiftData

enum SyncSource: String, Codable {
    case github
    case oura
}

enum SyncStatus: String, Codable {
    case idle
    case syncing
    case success
    case failed
}

@Model
final class SyncState {
    @Attribute(.unique) var source: String
    var lastSyncDate: Date?
    var lastSyncStatus: String
    var lastError: String?
    var totalRecordsSynced: Int

    init(
        source: SyncSource,
        lastSyncDate: Date? = nil,
        lastSyncStatus: SyncStatus = .idle,
        lastError: String? = nil,
        totalRecordsSynced: Int = 0
    ) {
        self.source = source.rawValue
        self.lastSyncDate = lastSyncDate
        self.lastSyncStatus = lastSyncStatus.rawValue
        self.lastError = lastError
        self.totalRecordsSynced = totalRecordsSynced
    }

    var syncSource: SyncSource {
        SyncSource(rawValue: source) ?? .github
    }

    var status: SyncStatus {
        get { SyncStatus(rawValue: lastSyncStatus) ?? .idle }
        set { lastSyncStatus = newValue.rawValue }
    }

    var lastSyncDescription: String {
        guard let date = lastSyncDate else { return "Never synced" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Synced \(formatter.localizedString(for: date, relativeTo: .now))"
    }
}

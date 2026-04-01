import Foundation
import SwiftData

@Model
final class CommitRecord {
    @Attribute(.unique) var sha: String
    var repoFullName: String
    var authorDate: Date
    var message: String
    var additions: Int
    var deletions: Int
    var dayKey: String
    var hourOfDay: Int
    var hasDetailedStats: Bool

    init(
        sha: String,
        repoFullName: String,
        authorDate: Date,
        message: String,
        additions: Int = 0,
        deletions: Int = 0,
        hasDetailedStats: Bool = false
    ) {
        self.sha = sha
        self.repoFullName = repoFullName
        self.authorDate = authorDate
        self.message = message
        self.additions = additions
        self.deletions = deletions
        self.dayKey = DateHelpers.dayKey(from: authorDate)
        self.hourOfDay = Calendar.current.component(.hour, from: authorDate)
        self.hasDetailedStats = hasDetailedStats
    }

    var totalChanges: Int { additions + deletions }
}

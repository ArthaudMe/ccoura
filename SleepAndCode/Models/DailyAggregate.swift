import Foundation
import SwiftData

@Model
final class DailyAggregate {
    @Attribute(.unique) var dayKey: String
    var commitCount: Int
    var totalAdditions: Int
    var totalDeletions: Int
    var activeHoursCount: Int
    var avgCommitSize: Double
    var qualityScore: Double

    init(
        dayKey: String,
        commitCount: Int,
        totalAdditions: Int = 0,
        totalDeletions: Int = 0,
        activeHoursCount: Int = 0,
        avgCommitSize: Double = 0,
        qualityScore: Double = 0
    ) {
        self.dayKey = dayKey
        self.commitCount = commitCount
        self.totalAdditions = totalAdditions
        self.totalDeletions = totalDeletions
        self.activeHoursCount = activeHoursCount
        self.avgCommitSize = avgCommitSize
        self.qualityScore = qualityScore
    }

    var totalChanges: Int { totalAdditions + totalDeletions }

    /// Compute the "commit quality" composite score (0-100)
    static func computeQualityScore(
        commitCount: Int,
        totalChanges: Int,
        activeHours: Int,
        avgCommitSize: Double
    ) -> Double {
        let commitScore = min(Double(commitCount) / 10.0, 1.0) * 30.0
        let changesScore = min(Double(totalChanges) / 500.0, 1.0) * 30.0
        let focusScore = min(Double(activeHours) / 8.0, 1.0) * 20.0
        let sizeScore = min(avgCommitSize / 100.0, 1.0) * 20.0
        return commitScore + changesScore + focusScore + sizeScore
    }
}

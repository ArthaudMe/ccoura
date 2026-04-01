import Foundation

struct InsightData {
    let key: String
    let title: String
    let body: String
    let category: InsightCategory
    let relevanceScore: Double
}

enum InsightTemplates {

    // MARK: - Sleep-Commit Correlation

    /// Generates an insight about the correlation between sleep score and commit count.
    /// Returns nil if the correlation is too weak (|r| <= 0.2) or sample size is too small.
    static func sleepCommitCorrelation(r: Double, n: Int) -> InsightData? {
        guard abs(r) > 0.2, n >= 14 else { return nil }

        let strength: String
        let relevance: Double

        switch abs(r) {
        case 0.6...:
            strength = "strongly"
            relevance = 0.95
        case 0.4..<0.6:
            strength = "moderately"
            relevance = 0.8
        default:
            strength = "mildly"
            relevance = 0.6
        }

        let direction = r > 0 ? "positively" : "negatively"
        let rFormatted = String(format: "%.2f", r)

        return InsightData(
            key: "sleep_commit_correlation",
            title: "Sleep & Coding Are \(strength.capitalized) Linked",
            body: "Your sleep quality and coding output are \(strength) \(direction) correlated (r=\(rFormatted)) based on \(n) days of data. \(r > 0 ? "Better sleep tends to lead to more productive coding days." : "An inverse pattern suggests other factors may dominate your coding output.")",
            category: .correlation,
            relevanceScore: relevance
        )
    }

    // MARK: - Poor Sleep Impact

    /// Generates an insight about the productivity impact of poor sleep.
    /// Returns nil if the difference is less than 15%.
    static func poorSleepImpact(
        avgCommitsPoor: Double,
        avgCommitsGood: Double
    ) -> InsightData? {
        guard avgCommitsGood > 0 else { return nil }

        let percentDiff = ((avgCommitsGood - avgCommitsPoor) / avgCommitsGood) * 100
        guard percentDiff > 15 else { return nil }

        let relevance = min(0.95, 0.6 + (percentDiff / 100.0))
        let pctFormatted = String(format: "%.0f", percentDiff)
        let poorFormatted = String(format: "%.1f", avgCommitsPoor)
        let goodFormatted = String(format: "%.1f", avgCommitsGood)

        return InsightData(
            key: "poor_sleep_impact",
            title: "Poor Sleep Costs You \(pctFormatted)% Productivity",
            body: "After poor sleep, you average \(poorFormatted) commits compared to \(goodFormatted) after good sleep -- a \(pctFormatted)% drop. Prioritizing sleep quality could directly boost your coding output.",
            category: .sleepImpact,
            relevanceScore: relevance
        )
    }

    // MARK: - Optimal Sleep Duration

    /// Generates an insight about the ideal sleep duration for productivity.
    /// Returns nil if the range is unreasonably wide (> 3 hours).
    static func optimalSleepDuration(
        low: Double,
        high: Double,
        avgCommits: Double
    ) -> InsightData? {
        let rangeWidth = high - low
        guard rangeWidth > 0, rangeWidth <= 3.0 else { return nil }

        let relevance = min(0.9, 0.65 + (1.0 / rangeWidth) * 0.1)
        let lowFormatted = formatHoursMinutes(low)
        let highFormatted = formatHoursMinutes(high)
        let commitsFormatted = String(format: "%.1f", avgCommits)

        return InsightData(
            key: "optimal_sleep_duration",
            title: "Your Sweet Spot: \(lowFormatted)-\(highFormatted) of Sleep",
            body: "Your most productive coding days (averaging \(commitsFormatted) commits) follow \(lowFormatted) to \(highFormatted) of sleep. Aim for this range to maximize your output.",
            category: .productivity,
            relevanceScore: relevance
        )
    }

    // MARK: - Deep Sleep Impact

    /// Generates an insight about the impact of deep sleep on coding.
    /// Returns nil if the correlation is too weak or the difference is too small.
    static func deepSleepImpact(
        r: Double,
        avgCommitsHighDeep: Double,
        avgCommitsLowDeep: Double
    ) -> InsightData? {
        guard abs(r) > 0.2 else { return nil }

        let totalAvg = (avgCommitsHighDeep + avgCommitsLowDeep) / 2.0
        guard totalAvg > 0 else { return nil }

        let percentDiff = ((avgCommitsHighDeep - avgCommitsLowDeep) / totalAvg) * 100
        guard percentDiff > 15 else { return nil }

        let relevance = min(0.9, 0.6 + abs(r) * 0.3)
        let pctFormatted = String(format: "%.0f", percentDiff)
        let highFormatted = String(format: "%.1f", avgCommitsHighDeep)
        let lowFormatted = String(format: "%.1f", avgCommitsLowDeep)

        return InsightData(
            key: "deep_sleep_impact",
            title: "Deep Sleep Boosts Output by \(pctFormatted)%",
            body: "When you get above-average deep sleep, you commit \(highFormatted) times vs \(lowFormatted) times on low deep sleep nights -- a \(pctFormatted)% difference. Deep sleep is critical for cognitive recovery and coding performance.",
            category: .sleepImpact,
            relevanceScore: relevance
        )
    }

    // MARK: - Best Day of Week

    /// Generates an insight about the most productive day of the week.
    /// Returns nil if the difference from the overall average is less than 15%.
    static func bestDayOfWeek(
        day: String,
        avgCommits: Double,
        overallAvg: Double
    ) -> InsightData? {
        guard overallAvg > 0 else { return nil }

        let percentAbove = ((avgCommits - overallAvg) / overallAvg) * 100
        guard percentAbove > 15 else { return nil }

        let relevance = min(0.85, 0.5 + (percentAbove / 200.0))
        let pctFormatted = String(format: "%.0f", percentAbove)
        let commitsFormatted = String(format: "%.1f", avgCommits)

        return InsightData(
            key: "best_day_\(day.lowercased())",
            title: "\(day)s Are Your Power Day",
            body: "You average \(commitsFormatted) commits on \(day)s -- \(pctFormatted)% above your daily average. Consider scheduling your most important coding work on \(day)s.",
            category: .timing,
            relevanceScore: relevance
        )
    }

    // MARK: - Streak Alert

    /// Generates an insight about a consecutive sleep quality streak.
    /// Returns nil if the streak is less than 3 days.
    static func streakAlert(days: Int, avgScore: Double) -> InsightData? {
        guard days >= 3 else { return nil }

        let relevance = min(0.9, 0.5 + Double(days) * 0.05)
        let scoreFormatted = String(format: "%.0f", avgScore)

        let encouragement: String
        switch days {
        case 3..<5:
            encouragement = "Keep the momentum going!"
        case 5..<7:
            encouragement = "Impressive consistency -- your body is thanking you."
        default:
            encouragement = "Outstanding dedication to sleep health!"
        }

        return InsightData(
            key: "streak_alert",
            title: "\(days)-Day Sleep Streak!",
            body: "You've maintained \(days) consecutive days with sleep scores above 80 (averaging \(scoreFormatted)). \(encouragement)",
            category: .streak,
            relevanceScore: relevance
        )
    }

    // MARK: - Weekly Recap

    /// Generates a weekly summary insight.
    static func weeklyRecap(
        avgSleep: Double,
        totalCommits: Int,
        bestDay: String,
        bestDayHours: Double
    ) -> InsightData? {
        let sleepFormatted = String(format: "%.1f", avgSleep)
        let hoursFormatted = formatHoursMinutes(bestDayHours)

        return InsightData(
            key: "weekly_recap",
            title: "Your Week in Review",
            body: "This week: \(sleepFormatted)h average sleep, \(totalCommits) total commits. Your best day was \(bestDay) after \(hoursFormatted) of sleep. \(avgSleep >= 7.0 ? "Solid sleep habits this week!" : "Consider aiming for 7+ hours to boost next week's productivity.")",
            category: .weekly,
            relevanceScore: 0.7
        )
    }

    // MARK: - Helpers

    private static func formatHoursMinutes(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }
}

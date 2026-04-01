import Foundation
import SwiftData

@ModelActor
actor InsightsEngine {

    private static let minimumOverlapDays = Constants.Data.minimumInsightDays

    // MARK: - Public API

    /// Checks whether there is enough overlapping sleep and commit data
    /// to generate meaningful insights.
    func hasEnoughData() -> Bool {
        let (current, required) = dataProgress()
        return current >= required
    }

    /// Returns the current number of overlapping data days and the
    /// minimum required, useful for displaying a ramp-up progress bar.
    func dataProgress() -> (current: Int, required: Int) {
        let overlapCount = (try? countOverlappingDays()) ?? 0
        return (current: overlapCount, required: Self.minimumOverlapDays)
    }

    /// Generates all available insights from sleep and commit data,
    /// persists them as CachedInsight records, and returns the sorted results.
    func generateInsights() async throws -> [CachedInsight] {
        let sleepRecords = try modelContext.fetch(
            FetchDescriptor<SleepRecord>(sortBy: [SortDescriptor(\.dayKey)])
        )
        let aggregates = try modelContext.fetch(
            FetchDescriptor<DailyAggregate>(sortBy: [SortDescriptor(\.dayKey)])
        )

        let pairedData = buildPairedData(sleepRecords: sleepRecords, aggregates: aggregates)

        guard pairedData.count >= Self.minimumOverlapDays else {
            return try fetchExistingInsights()
        }

        var insights: [InsightData] = []

        insights.append(contentsOf: computeCorrelationInsights(pairedData))
        insights.append(contentsOf: computeBracketInsights(pairedData))
        insights.append(contentsOf: computeOptimalSleepInsights(pairedData))
        insights.append(contentsOf: computeDeepSleepInsights(pairedData))
        insights.append(contentsOf: computeDayOfWeekInsights(pairedData))
        insights.append(contentsOf: computeStreakInsights(sleepRecords))
        insights.append(contentsOf: computeWeeklyRecapInsights(pairedData))

        try upsertInsights(insights, dataPointCount: pairedData.count)

        return try fetchExistingInsights()
    }

    // MARK: - Paired Data

    private struct PairedDay {
        let sleepDayKey: String
        let commitDayKey: String
        let sleepScore: Int
        let totalSleepHours: Double
        let deepSleepSeconds: Int
        let commitCount: Int
    }

    /// Pairs sleep on day N with commits on day N+1 (next-day correlation).
    private func buildPairedData(
        sleepRecords: [SleepRecord],
        aggregates: [DailyAggregate]
    ) -> [PairedDay] {
        let aggregatesByDayKey = Dictionary(
            aggregates.map { ($0.dayKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var paired: [PairedDay] = []

        for sleep in sleepRecords {
            guard let sleepDate = DateHelpers.date(from: sleep.dayKey),
                  let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: sleepDate)
            else { continue }

            let nextDayKey = DateHelpers.dayKey(from: nextDate)

            guard let aggregate = aggregatesByDayKey[nextDayKey] else { continue }

            paired.append(PairedDay(
                sleepDayKey: sleep.dayKey,
                commitDayKey: nextDayKey,
                sleepScore: sleep.score,
                totalSleepHours: sleep.totalSleepHours,
                deepSleepSeconds: sleep.deepSleepSeconds,
                commitCount: aggregate.commitCount
            ))
        }

        return paired
    }

    // MARK: - Correlation Insights

    private func computeCorrelationInsights(_ data: [PairedDay]) -> [InsightData] {
        let scores = data.map { Double($0.sleepScore) }
        let commits = data.map { Double($0.commitCount) }

        guard let r = CorrelationCalculator.pearsonCorrelation(x: scores, y: commits) else {
            return []
        }

        if let insight = InsightTemplates.sleepCommitCorrelation(r: r, n: data.count) {
            return [insight]
        }
        return []
    }

    // MARK: - Bracket Insights

    private func computeBracketInsights(_ data: [PairedDay]) -> [InsightData] {
        let sleepScores = data.map { $0.sleepScore }
        let commitCounts = data.map { $0.commitCount }

        let brackets = CorrelationCalculator.bracketAnalysis(
            sleepScores: sleepScores,
            commitCounts: commitCounts
        )

        var insights: [InsightData] = []

        let poorAvg = brackets.first { $0.0 == .poor }?.1
        let goodAvg = brackets.first { $0.0 == .good }?.1
        let excellentAvg = brackets.first { $0.0 == .excellent }?.1

        // Use the higher of good or excellent as the comparison baseline
        let bestAvg = [goodAvg, excellentAvg].compactMap { $0 }.max()

        if let poor = poorAvg, let best = bestAvg {
            if let insight = InsightTemplates.poorSleepImpact(
                avgCommitsPoor: poor,
                avgCommitsGood: best
            ) {
                insights.append(insight)
            }
        }

        return insights
    }

    // MARK: - Optimal Sleep Insights

    private func computeOptimalSleepInsights(_ data: [PairedDay]) -> [InsightData] {
        let sleepHours = data.map { $0.totalSleepHours }
        let commitCounts = data.map { $0.commitCount }

        guard let range = CorrelationCalculator.optimalSleepRange(
            sleepHours: sleepHours,
            commitCounts: commitCounts
        ) else {
            return []
        }

        // Calculate average commits within the optimal range
        let inRangeCommits = data
            .filter { $0.totalSleepHours >= range.low && $0.totalSleepHours < range.high }
            .map { $0.commitCount }

        guard !inRangeCommits.isEmpty else { return [] }
        let avgCommits = Double(inRangeCommits.reduce(0, +)) / Double(inRangeCommits.count)

        if let insight = InsightTemplates.optimalSleepDuration(
            low: range.low,
            high: range.high,
            avgCommits: avgCommits
        ) {
            return [insight]
        }
        return []
    }

    // MARK: - Deep Sleep Insights

    private func computeDeepSleepInsights(_ data: [PairedDay]) -> [InsightData] {
        let deepSleepMinutes = data.map { Double($0.deepSleepSeconds) / 60.0 }
        let commits = data.map { Double($0.commitCount) }

        guard let r = CorrelationCalculator.pearsonCorrelation(
            x: deepSleepMinutes,
            y: commits
        ) else {
            return []
        }

        // Split into above/below median deep sleep
        let sortedDeep = deepSleepMinutes.sorted()
        let median = sortedDeep[sortedDeep.count / 2]

        let highDeepCommits = zip(deepSleepMinutes, data)
            .filter { $0.0 >= median }
            .map { $0.1.commitCount }

        let lowDeepCommits = zip(deepSleepMinutes, data)
            .filter { $0.0 < median }
            .map { $0.1.commitCount }

        guard !highDeepCommits.isEmpty, !lowDeepCommits.isEmpty else { return [] }

        let avgHigh = Double(highDeepCommits.reduce(0, +)) / Double(highDeepCommits.count)
        let avgLow = Double(lowDeepCommits.reduce(0, +)) / Double(lowDeepCommits.count)

        if let insight = InsightTemplates.deepSleepImpact(
            r: r,
            avgCommitsHighDeep: avgHigh,
            avgCommitsLowDeep: avgLow
        ) {
            return [insight]
        }
        return []
    }

    // MARK: - Day of Week Insights

    private func computeDayOfWeekInsights(_ data: [PairedDay]) -> [InsightData] {
        let dayKeys = data.map { $0.commitDayKey }
        let commitCounts = data.map { $0.commitCount }

        let dayAnalysis = CorrelationCalculator.dayOfWeekAnalysis(
            dayKeys: dayKeys,
            commitCounts: commitCounts
        )

        guard !dayAnalysis.isEmpty else { return [] }

        let overallAvg = Double(commitCounts.reduce(0, +)) / Double(commitCounts.count)

        // Find the best day
        guard let best = dayAnalysis.max(by: { $0.1 < $1.1 }) else { return [] }

        if let insight = InsightTemplates.bestDayOfWeek(
            day: best.0,
            avgCommits: best.1,
            overallAvg: overallAvg
        ) {
            return [insight]
        }
        return []
    }

    // MARK: - Streak Insights

    private func computeStreakInsights(_ sleepRecords: [SleepRecord]) -> [InsightData] {
        let sorted = sleepRecords.sorted { $0.dayKey < $1.dayKey }
        guard !sorted.isEmpty else { return [] }

        // Find the current streak of scores >= 80 ending at the most recent record
        var streakDays = 0
        var streakScoreSum = 0.0

        for record in sorted.reversed() {
            if record.score >= 80 {
                streakDays += 1
                streakScoreSum += Double(record.score)
            } else {
                break
            }
        }

        guard streakDays > 0 else { return [] }

        let avgScore = streakScoreSum / Double(streakDays)

        if let insight = InsightTemplates.streakAlert(days: streakDays, avgScore: avgScore) {
            return [insight]
        }
        return []
    }

    // MARK: - Weekly Recap Insights

    private func computeWeeklyRecapInsights(_ data: [PairedDay]) -> [InsightData] {
        // Use the last 7 days of paired data
        let recentData = Array(data.suffix(7))
        guard recentData.count >= 3 else { return [] }

        let avgSleep = recentData.map(\.totalSleepHours).reduce(0, +) / Double(recentData.count)
        let totalCommits = recentData.map(\.commitCount).reduce(0, +)

        // Find the day with the most commits
        guard let bestPair = recentData.max(by: { $0.commitCount < $1.commitCount }),
              let bestDayName = DateHelpers.dayOfWeek(for: bestPair.commitDayKey)
        else { return [] }

        if let insight = InsightTemplates.weeklyRecap(
            avgSleep: avgSleep,
            totalCommits: totalCommits,
            bestDay: bestDayName,
            bestDayHours: bestPair.totalSleepHours
        ) {
            return [insight]
        }
        return []
    }

    // MARK: - Persistence

    /// Upserts insight data into CachedInsight records. Existing insights
    /// with the same key are updated; new ones are inserted.
    private func upsertInsights(_ insights: [InsightData], dataPointCount: Int) throws {
        for insight in insights {
            let key = insight.key
            let descriptor = FetchDescriptor<CachedInsight>(
                predicate: #Predicate<CachedInsight> { $0.insightKey == key }
            )

            let existing = try modelContext.fetch(descriptor)

            if let cached = existing.first {
                cached.title = insight.title
                cached.body = insight.body
                cached.category = insight.category.rawValue
                cached.relevanceScore = insight.relevanceScore
                cached.generatedAt = .now
                cached.dataPointCount = dataPointCount
            } else {
                let cached = CachedInsight(
                    insightKey: insight.key,
                    title: insight.title,
                    body: insight.body,
                    category: insight.category,
                    relevanceScore: insight.relevanceScore,
                    dataPointCount: dataPointCount
                )
                modelContext.insert(cached)
            }
        }

        try modelContext.save()
    }

    /// Fetches all cached insights sorted by relevance score descending.
    private func fetchExistingInsights() throws -> [CachedInsight] {
        let descriptor = FetchDescriptor<CachedInsight>(
            sortBy: [SortDescriptor(\.relevanceScore, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Counts the number of days where both sleep and commit data overlap
    /// (sleep on day N, commits on day N+1).
    private func countOverlappingDays() throws -> Int {
        let sleepRecords = try modelContext.fetch(FetchDescriptor<SleepRecord>())
        let aggregates = try modelContext.fetch(FetchDescriptor<DailyAggregate>())

        let aggregateDayKeys = Set(aggregates.map(\.dayKey))

        var overlapCount = 0
        for sleep in sleepRecords {
            guard let sleepDate = DateHelpers.date(from: sleep.dayKey),
                  let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: sleepDate)
            else { continue }

            let nextDayKey = DateHelpers.dayKey(from: nextDate)
            if aggregateDayKeys.contains(nextDayKey) {
                overlapCount += 1
            }
        }

        return overlapCount
    }
}

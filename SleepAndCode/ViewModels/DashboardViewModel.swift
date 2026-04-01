import Foundation
import SwiftData
import Observation

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case year = "1Y"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

struct DayDataPoint: Identifiable {
    let id: String
    let dayKey: String
    let date: Date
    let sleepScore: Int?
    let commitCount: Int
    let totalChanges: Int
    let qualityScore: Double
    let sleepHours: Double?

    init(dayKey: String, sleep: SleepRecord?, aggregate: DailyAggregate?) {
        self.id = dayKey
        self.dayKey = dayKey
        self.date = DateHelpers.date(from: dayKey) ?? .now
        self.sleepScore = sleep?.score
        self.commitCount = aggregate?.commitCount ?? 0
        self.totalChanges = aggregate?.totalChanges ?? 0
        self.qualityScore = aggregate?.qualityScore ?? 0
        self.sleepHours = sleep?.totalSleepHours
    }
}

struct ScatterPoint: Identifiable {
    let id = UUID()
    let sleepScore: Int
    let nextDayCommits: Int
}

struct BracketData: Identifiable {
    let id: String
    let quality: SleepQuality
    let avgCommits: Double

    init(quality: SleepQuality, avgCommits: Double) {
        self.id = quality.rawValue
        self.quality = quality
        self.avgCommits = avgCommits
    }
}

@MainActor
@Observable
final class DashboardViewModel {
    var timeRange: TimeRange = .month
    var dataPoints: [DayDataPoint] = []
    var scatterPoints: [ScatterPoint] = []
    var bracketData: [BracketData] = []
    var correlationCoefficient: Double?
    var avgCommitsGoodSleep: Double = 0
    var avgCommitsBadSleep: Double = 0
    var totalCommits: Int = 0
    var totalDays: Int = 0
    var isLoading = false

    func loadData(modelContext: ModelContext) {
        isLoading = true
        defer { isLoading = false }

        let startKey = DateHelpers.dayKeyDaysAgo(timeRange.days)
        let endKey = DateHelpers.today()

        // Fetch sleep records
        let sleepPredicate = #Predicate<SleepRecord> {
            $0.dayKey >= startKey && $0.dayKey <= endKey
        }
        let sleepRecords = (try? modelContext.fetch(
            FetchDescriptor<SleepRecord>(predicate: sleepPredicate)
        )) ?? []
        let sleepByDay = Dictionary(uniqueKeysWithValues: sleepRecords.map { ($0.dayKey, $0) })

        // Fetch aggregates
        let aggPredicate = #Predicate<DailyAggregate> {
            $0.dayKey >= startKey && $0.dayKey <= endKey
        }
        let aggregates = (try? modelContext.fetch(
            FetchDescriptor<DailyAggregate>(predicate: aggPredicate)
        )) ?? []
        let aggByDay = Dictionary(uniqueKeysWithValues: aggregates.map { ($0.dayKey, $0) })

        // Build data points for every day in range
        let allDays = DateHelpers.allDayKeys(from: startKey, to: endKey)
        dataPoints = allDays.map { day in
            DayDataPoint(dayKey: day, sleep: sleepByDay[day], aggregate: aggByDay[day])
        }

        // Scatter: sleep score on day N → commits on day N+1
        var scatter: [ScatterPoint] = []
        for i in 0..<(allDays.count - 1) {
            let today = allDays[i]
            let tomorrow = allDays[i + 1]
            if let sleep = sleepByDay[today], let agg = aggByDay[tomorrow] {
                scatter.append(ScatterPoint(sleepScore: sleep.score, nextDayCommits: agg.commitCount))
            }
        }
        scatterPoints = scatter

        // Bracket analysis
        let bracketMap = Dictionary(grouping: scatter, by: { SleepQuality.from(score: $0.sleepScore) })
        bracketData = SleepQuality.allCases.map { quality in
            let points = bracketMap[quality] ?? []
            let avg = points.isEmpty ? 0 : Double(points.reduce(0) { $0 + $1.nextDayCommits }) / Double(points.count)
            return BracketData(quality: quality, avgCommits: avg)
        }

        // Pearson correlation
        if scatter.count >= 5 {
            let x = scatter.map { Double($0.sleepScore) }
            let y = scatter.map { Double($0.nextDayCommits) }
            correlationCoefficient = CorrelationCalculator.pearsonCorrelation(x: x, y: y)
        } else {
            correlationCoefficient = nil
        }

        // Comparative averages
        let goodSleep = scatter.filter { $0.sleepScore >= 70 }
        let badSleep = scatter.filter { $0.sleepScore < 70 }
        avgCommitsGoodSleep = goodSleep.isEmpty ? 0 : Double(goodSleep.reduce(0) { $0 + $1.nextDayCommits }) / Double(goodSleep.count)
        avgCommitsBadSleep = badSleep.isEmpty ? 0 : Double(badSleep.reduce(0) { $0 + $1.nextDayCommits }) / Double(badSleep.count)

        totalCommits = aggregates.reduce(0) { $0 + $1.commitCount }
        totalDays = allDays.count
    }
}

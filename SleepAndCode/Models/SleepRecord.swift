import Foundation
import SwiftData

@Model
final class SleepRecord {
    @Attribute(.unique) var dayKey: String
    var score: Int
    var totalSleepSeconds: Int
    var remSleepSeconds: Int
    var deepSleepSeconds: Int
    var lightSleepSeconds: Int
    var efficiency: Int
    var restingHeartRate: Double?
    var hrv: Double?
    var bedtimeStart: Date?
    var bedtimeEnd: Date?

    init(
        dayKey: String,
        score: Int,
        totalSleepSeconds: Int,
        remSleepSeconds: Int = 0,
        deepSleepSeconds: Int = 0,
        lightSleepSeconds: Int = 0,
        efficiency: Int = 0,
        restingHeartRate: Double? = nil,
        hrv: Double? = nil,
        bedtimeStart: Date? = nil,
        bedtimeEnd: Date? = nil
    ) {
        self.dayKey = dayKey
        self.score = score
        self.totalSleepSeconds = totalSleepSeconds
        self.remSleepSeconds = remSleepSeconds
        self.deepSleepSeconds = deepSleepSeconds
        self.lightSleepSeconds = lightSleepSeconds
        self.efficiency = efficiency
        self.restingHeartRate = restingHeartRate
        self.hrv = hrv
        self.bedtimeStart = bedtimeStart
        self.bedtimeEnd = bedtimeEnd
    }

    var totalSleepHours: Double {
        Double(totalSleepSeconds) / 3600.0
    }

    var sleepQuality: SleepQuality {
        SleepQuality.from(score: score)
    }
}

enum SleepQuality: String, CaseIterable {
    case poor = "Poor"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"

    static func from(score: Int) -> SleepQuality {
        switch score {
        case ..<60: return .poor
        case 60..<70: return .fair
        case 70..<85: return .good
        default: return .excellent
        }
    }

    var color: String {
        switch self {
        case .poor: return "red"
        case .fair: return "orange"
        case .good: return "blue"
        case .excellent: return "green"
        }
    }
}

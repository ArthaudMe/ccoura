import Foundation

enum CorrelationCalculator {

    // MARK: - Pearson Correlation

    /// Computes the Pearson correlation coefficient between two datasets.
    /// Returns nil if fewer than 5 paired data points or zero variance.
    static func pearsonCorrelation(x: [Double], y: [Double]) -> Double? {
        let n = min(x.count, y.count)
        guard n >= 5 else { return nil }

        let xSlice = Array(x.prefix(n))
        let ySlice = Array(y.prefix(n))

        let sumX = xSlice.reduce(0, +)
        let sumY = ySlice.reduce(0, +)
        let sumXY = zip(xSlice, ySlice).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumX2 = xSlice.reduce(0.0) { $0 + $1 * $1 }
        let sumY2 = ySlice.reduce(0.0) { $0 + $1 * $1 }

        let count = Double(n)
        let numerator = count * sumXY - sumX * sumY
        let denominator = sqrt((count * sumX2 - sumX * sumX) * (count * sumY2 - sumY * sumY))

        guard denominator > .ulpOfOne else { return nil }

        let r = numerator / denominator
        return max(-1.0, min(1.0, r))
    }

    // MARK: - Moving Average

    /// Computes a simple moving average with the given window size.
    /// Returns an array of the same length with the first (window - 1) values
    /// computed using a smaller window (expanding window for leading values).
    static func movingAverage(values: [Double], window: Int) -> [Double] {
        guard !values.isEmpty else { return [] }
        let w = max(1, window)
        var result = [Double]()
        result.reserveCapacity(values.count)

        var runningSum = 0.0
        for i in 0..<values.count {
            runningSum += values[i]
            if i >= w {
                runningSum -= values[i - w]
                result.append(runningSum / Double(w))
            } else {
                result.append(runningSum / Double(i + 1))
            }
        }
        return result
    }

    // MARK: - Bracket Analysis

    /// Groups data points by sleep quality bracket and computes the average
    /// commit count for each bracket.
    static func bracketAnalysis(
        sleepScores: [Int],
        commitCounts: [Int]
    ) -> [(SleepQuality, Double)] {
        let n = min(sleepScores.count, commitCounts.count)
        guard n > 0 else { return [] }

        var buckets: [SleepQuality: [Int]] = [:]

        for i in 0..<n {
            let quality = SleepQuality.from(score: sleepScores[i])
            buckets[quality, default: []].append(commitCounts[i])
        }

        return SleepQuality.allCases.compactMap { quality in
            guard let values = buckets[quality], !values.isEmpty else { return nil }
            let avg = Double(values.reduce(0, +)) / Double(values.count)
            return (quality, avg)
        }
    }

    // MARK: - Optimal Sleep Range

    /// Buckets sleep hours into 30-minute intervals and finds the range with
    /// the highest average commit count. Returns nil if insufficient data.
    static func optimalSleepRange(
        sleepHours: [Double],
        commitCounts: [Int]
    ) -> (low: Double, high: Double)? {
        let n = min(sleepHours.count, commitCounts.count)
        guard n >= 5 else { return nil }

        // Group by 30-minute buckets: 5.0, 5.5, 6.0, ...
        var buckets: [Double: [Int]] = [:]

        for i in 0..<n {
            let bucketKey = (sleepHours[i] * 2).rounded(.down) / 2.0
            buckets[bucketKey, default: []].append(commitCounts[i])
        }

        // Only consider buckets with at least 2 data points
        let validBuckets = buckets.filter { $0.value.count >= 2 }
        guard !validBuckets.isEmpty else { return nil }

        let averages = validBuckets.mapValues { values in
            Double(values.reduce(0, +)) / Double(values.count)
        }

        // Find the bucket with the highest average
        guard let peakBucket = averages.max(by: { $0.value < $1.value }) else {
            return nil
        }

        // Expand the range to include adjacent buckets that are within 80% of the peak
        let threshold = peakBucket.value * 0.8
        let sortedKeys = averages.keys.sorted()

        guard let peakIndex = sortedKeys.firstIndex(of: peakBucket.key) else {
            return nil
        }

        var low = peakBucket.key
        var high = peakBucket.key + 0.5

        // Expand downward
        var idx = peakIndex - 1
        while idx >= 0 {
            let key = sortedKeys[idx]
            if let avg = averages[key], avg >= threshold {
                low = key
                idx -= 1
            } else {
                break
            }
        }

        // Expand upward
        idx = peakIndex + 1
        while idx < sortedKeys.count {
            let key = sortedKeys[idx]
            if let avg = averages[key], avg >= threshold {
                high = key + 0.5
                idx += 1
            } else {
                break
            }
        }

        return (low: low, high: high)
    }

    // MARK: - Day of Week Analysis

    /// Computes average commit counts grouped by day of the week.
    /// `dayKeys` should be in "yyyy-MM-dd" format.
    static func dayOfWeekAnalysis(
        dayKeys: [String],
        commitCounts: [Int]
    ) -> [(String, Double)] {
        let n = min(dayKeys.count, commitCounts.count)
        guard n > 0 else { return [] }

        var buckets: [String: [Int]] = [:]

        for i in 0..<n {
            guard let weekday = DateHelpers.dayOfWeek(for: dayKeys[i]) else { continue }
            buckets[weekday, default: []].append(commitCounts[i])
        }

        let weekdayOrder = [
            "Monday", "Tuesday", "Wednesday", "Thursday",
            "Friday", "Saturday", "Sunday"
        ]

        return weekdayOrder.compactMap { day in
            guard let values = buckets[day], !values.isEmpty else { return nil }
            let avg = Double(values.reduce(0, +)) / Double(values.count)
            return (day, avg)
        }
    }
}

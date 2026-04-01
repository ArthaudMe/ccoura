import SwiftUI
import Charts

struct DualAxisChartView: View {
    let dataPoints: [DayDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Score vs Commits")
                .font(.headline)

            Chart {
                ForEach(dataPoints) { point in
                    if point.commitCount > 0 {
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Commits", point.commitCount)
                        )
                        .foregroundStyle(.blue.opacity(0.6))
                    }
                }

                ForEach(dataPoints.filter { $0.sleepScore != nil }) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Sleep", Double(point.sleepScore!) / maxSleepScale * maxCommitCount)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxisLabel("Commits", position: .leading)

            // Legend
            HStack(spacing: 16) {
                Label("Commits", systemImage: "square.fill")
                    .font(.caption)
                    .foregroundStyle(.blue.opacity(0.6))
                Label("Sleep Score", systemImage: "line.diagonal")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var maxCommitCount: Double {
        max(Double(dataPoints.map(\.commitCount).max() ?? 1), 1)
    }

    private var maxSleepScale: Double { 100.0 }
}

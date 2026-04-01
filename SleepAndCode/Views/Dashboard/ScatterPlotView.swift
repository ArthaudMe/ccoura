import SwiftUI
import Charts

struct ScatterPlotView: View {
    let points: [ScatterPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Score vs Next-Day Commits")
                .font(.headline)

            Chart(points) { point in
                PointMark(
                    x: .value("Sleep Score", point.sleepScore),
                    y: .value("Commits", point.nextDayCommits)
                )
                .foregroundStyle(.purple.opacity(0.7))
                .symbolSize(40)
            }
            .chartXAxisLabel("Sleep Score")
            .chartYAxisLabel("Commits (next day)")
            .chartXScale(domain: 30...100)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

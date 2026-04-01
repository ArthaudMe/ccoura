import SwiftUI
import Charts

struct BracketChartView: View {
    let data: [BracketData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Avg Commits by Sleep Quality")
                .font(.headline)

            Chart(data) { bracket in
                BarMark(
                    x: .value("Quality", bracket.quality.rawValue),
                    y: .value("Avg Commits", bracket.avgCommits)
                )
                .foregroundStyle(by: .value("Quality", bracket.quality.rawValue))
                .annotation(position: .top) {
                    if bracket.avgCommits > 0 {
                        Text(String(format: "%.1f", bracket.avgCommits))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartForegroundStyleScale([
                "Poor": Color.red,
                "Fair": Color.orange,
                "Good": Color.blue,
                "Excellent": Color.green,
            ])
            .chartLegend(.hidden)
            .chartYAxisLabel("Avg Commits")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

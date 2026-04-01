import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    Picker("Time Range", selection: $viewModel.timeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if viewModel.dataPoints.isEmpty && !viewModel.isLoading {
                        EmptyStateView(
                            icon: "chart.xyaxis.line",
                            title: "No Data Yet",
                            message: "Connect GitHub and Oura in Settings to start tracking."
                        )
                        .padding(.top, 60)
                    } else {
                        // Stat cards
                        statsSection

                        // Dual axis chart
                        DualAxisChartView(dataPoints: viewModel.dataPoints)
                            .frame(height: 260)
                            .padding(.horizontal)

                        // Scatter plot
                        if !viewModel.scatterPoints.isEmpty {
                            ScatterPlotView(points: viewModel.scatterPoints)
                                .frame(height: 260)
                                .padding(.horizontal)
                        }

                        // Bracket chart
                        if viewModel.bracketData.contains(where: { $0.avgCommits > 0 }) {
                            BracketChartView(data: viewModel.bracketData)
                                .frame(height: 220)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .onAppear { viewModel.loadData(modelContext: modelContext) }
            .onChange(of: viewModel.timeRange) { _, _ in
                viewModel.loadData(modelContext: modelContext)
            }
        }
    }

    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            StatCardView(
                title: "Commits",
                value: "\(viewModel.totalCommits)",
                subtitle: "in \(viewModel.totalDays) days",
                icon: "curlybraces"
            )

            if let r = viewModel.correlationCoefficient {
                StatCardView(
                    title: "Correlation",
                    value: String(format: "%.2f", r),
                    subtitle: correlationLabel(r),
                    icon: "arrow.triangle.branch"
                )
            }

            if viewModel.avgCommitsGoodSleep > 0 {
                StatCardView(
                    title: "Good Sleep",
                    value: String(format: "%.1f", viewModel.avgCommitsGoodSleep),
                    subtitle: "avg commits/day",
                    icon: "moon.fill"
                )
            }

            if viewModel.avgCommitsBadSleep > 0 {
                StatCardView(
                    title: "Bad Sleep",
                    value: String(format: "%.1f", viewModel.avgCommitsBadSleep),
                    subtitle: "avg commits/day",
                    icon: "moon"
                )
            }
        }
        .padding(.horizontal)
    }

    private func correlationLabel(_ r: Double) -> String {
        let abs = abs(r)
        if abs < 0.2 { return "Weak" }
        if abs < 0.5 { return "Moderate" }
        return "Strong"
    }
}

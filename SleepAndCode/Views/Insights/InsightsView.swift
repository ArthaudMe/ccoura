import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    var modelContainer: ModelContainer

    @State private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Analyzing your data...")
                } else if !viewModel.hasEnoughData {
                    dataRampUpView
                } else if viewModel.insights.isEmpty {
                    EmptyStateView(
                        icon: "lightbulb",
                        title: "No Insights Yet",
                        message: "Keep syncing data — insights will appear as patterns emerge."
                    )
                } else {
                    insightsList
                }
            }
            .navigationTitle("Insights")
            .task {
                viewModel.loadCachedInsights(modelContext: modelContext)
                await viewModel.refreshInsights(modelContainer: modelContainer)
            }
        }
    }

    private var dataRampUpView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Building Your Profile")
                .font(.title2)
                .fontWeight(.bold)

            Text("We need at least \(Constants.Data.minimumInsightDays) days of overlapping sleep and commit data to generate insights.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            ProgressView(
                value: Double(viewModel.dataProgress.current),
                total: Double(viewModel.dataProgress.required)
            ) {
                Text("\(viewModel.dataProgress.current) / \(viewModel.dataProgress.required) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 48)
        }
    }

    private var insightsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.insights, id: \.insightKey) { insight in
                    InsightCardView(insight: insight)
                }
            }
            .padding()
        }
    }
}

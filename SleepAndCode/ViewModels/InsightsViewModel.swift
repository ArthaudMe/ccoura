import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class InsightsViewModel {
    var insights: [CachedInsight] = []
    var isLoading = false
    var hasEnoughData = false
    var dataProgress: (current: Int, required: Int) = (0, Constants.Data.minimumInsightDays)
    var errorMessage: String?

    func loadCachedInsights(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CachedInsight>(
            sortBy: [SortDescriptor(\.relevanceScore, order: .reverse)]
        )
        insights = (try? modelContext.fetch(descriptor)) ?? []
    }

    func refreshInsights(modelContainer: ModelContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let engine = InsightsEngine(modelContainer: modelContainer)

        do {
            hasEnoughData = try await engine.hasEnoughData()
            dataProgress = try await engine.dataProgress()

            if hasEnoughData {
                let generated = try await engine.generateInsights()
                insights = generated.sorted { $0.relevanceScore > $1.relevanceScore }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

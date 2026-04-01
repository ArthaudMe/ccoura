import Foundation
import SwiftData

enum InsightCategory: String, Codable, CaseIterable {
    case correlation
    case sleepImpact
    case productivity
    case timing
    case streak
    case weekly
}

@Model
final class CachedInsight {
    @Attribute(.unique) var insightKey: String
    var title: String
    var body: String
    var category: String
    var relevanceScore: Double
    var generatedAt: Date
    var dataPointCount: Int

    init(
        insightKey: String,
        title: String,
        body: String,
        category: InsightCategory,
        relevanceScore: Double,
        dataPointCount: Int = 0
    ) {
        self.insightKey = insightKey
        self.title = title
        self.body = body
        self.category = category.rawValue
        self.relevanceScore = relevanceScore
        self.generatedAt = .now
        self.dataPointCount = dataPointCount
    }

    var insightCategory: InsightCategory {
        InsightCategory(rawValue: category) ?? .correlation
    }
}

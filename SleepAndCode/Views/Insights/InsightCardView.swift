import SwiftUI

struct InsightCardView: View {
    let insight: CachedInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForCategory)
                    .foregroundStyle(colorForCategory)
                    .font(.title3)

                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(insight.insightCategory.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(colorForCategory.opacity(0.15), in: Capsule())
                    .foregroundStyle(colorForCategory)
            }

            Text(insight.body)
                .font(.body)
                .foregroundStyle(.primary)

            HStack {
                Text("Based on \(insight.dataPointCount) data points")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                relevanceDots
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var iconForCategory: String {
        switch insight.insightCategory {
        case .correlation: return "arrow.triangle.branch"
        case .sleepImpact: return "moon.zzz.fill"
        case .productivity: return "flame.fill"
        case .timing: return "clock.fill"
        case .streak: return "star.fill"
        case .weekly: return "calendar"
        }
    }

    private var colorForCategory: Color {
        switch insight.insightCategory {
        case .correlation: return .purple
        case .sleepImpact: return .blue
        case .productivity: return .orange
        case .timing: return .green
        case .streak: return .yellow
        case .weekly: return .teal
        }
    }

    private var relevanceDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Double(i) < insight.relevanceScore / 33.3 ? colorForCategory : .gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

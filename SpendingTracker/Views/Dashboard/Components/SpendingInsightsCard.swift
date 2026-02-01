//
//  SpendingInsightsCard.swift
//  SpendingTracker
//
//  Intelligent spending insights with contextual recommendations
//  Best Practice: Dashboards should tell a story, not just show numbers
//

import SwiftUI

// MARK: - Spending Insights Card (2026 Modern UI)

/// AI-style insights that provide context and actionable recommendations
struct SpendingInsightsCard: View {
    let insights: [SpendingInsight]

    @Environment(\.colorScheme) private var colorScheme

    init(insights: [SpendingInsight]) {
        self.insights = insights
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)

                Text("Insights")
                    .font(.headline)

                Spacer()
            }

            if insights.isEmpty {
                emptyState
            } else {
                // Simple list of insights (max 3)
                VStack(spacing: 10) {
                    ForEach(insights.prefix(3)) { insight in
                        InsightRow(insight: insight)
                    }
                }
            }
        }
        .padding(16)
        .background {
            glassBackground
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Keep tracking your spending")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Insights will appear as you add more transactions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.yellow.opacity(0.05))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.yellow.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    let insight: SpendingInsight

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(insight.type.color.opacity(colorScheme == .dark ? 0.2 : 0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: insight.type.icon)
                    .font(.body)
                    .foregroundStyle(insight.type.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                Text(insight.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Value/Badge
            if let value = insight.value {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(insight.type.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(insight.type.color.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Arrow
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Spending Insight Model

struct SpendingInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let subtitle: String
    let value: String?
    let relatedCategoryId: String?

    init(type: InsightType, title: String, subtitle: String, value: String? = nil, relatedCategoryId: String? = nil) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.relatedCategoryId = relatedCategoryId
    }
}

enum InsightType {
    case spending       // Spending pattern insight
    case savings        // Savings opportunity
    case warning        // Budget warning
    case achievement    // Positive achievement
    case tip            // General tip

    var icon: String {
        switch self {
        case .spending: return "chart.line.uptrend.xyaxis"
        case .savings: return "leaf.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .achievement: return "star.fill"
        case .tip: return "lightbulb.min.fill"
        }
    }

    var color: Color {
        switch self {
        case .spending: return .blue
        case .savings: return .green
        case .warning: return .orange
        case .achievement: return .yellow
        case .tip: return .purple
        }
    }
}

// MARK: - Insight Generator Helper

struct InsightGenerator {
    /// Generate insights based on transaction data
    static func generateInsights(
        categorySpending: [CategorySpending],
        totalExpense: Decimal,
        previousPeriodExpense: Decimal,
        topCategory: CategorySpending?
    ) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []

        // Top spending category insight
        if let top = topCategory {
            insights.append(SpendingInsight(
                type: .spending,
                title: "\(top.category.name) is your top expense",
                subtitle: "\(Int(top.percentage))% of your spending this period",
                value: top.formattedAmount,
                relatedCategoryId: top.id
            ))
        }

        // Spending trend insight
        if previousPeriodExpense > 0 {
            let change = ((totalExpense - previousPeriodExpense) / previousPeriodExpense) * 100
            let changePercent = (change as NSDecimalNumber).doubleValue

            if changePercent > 15 {
                insights.append(SpendingInsight(
                    type: .warning,
                    title: "Spending increased by \(Int(changePercent))%",
                    subtitle: "Compare to last period",
                    value: "+\(Int(changePercent))%"
                ))
            } else if changePercent < -10 {
                insights.append(SpendingInsight(
                    type: .achievement,
                    title: "Great job! Spending down \(abs(Int(changePercent)))%",
                    subtitle: "You're saving more this period",
                    value: "\(Int(changePercent))%"
                ))
            }
        }

        // Savings tip
        if insights.count < 3 {
            insights.append(SpendingInsight(
                type: .tip,
                title: "Track daily for better insights",
                subtitle: "Regular logging helps identify patterns"
            ))
        }

        return insights
    }
}

// MARK: - Preview

#Preview("Spending Insights") {
    let sampleInsights = [
        SpendingInsight(
            type: .spending,
            title: "Food & Dining is your top expense",
            subtitle: "35% of your spending this week",
            value: "₹4,500"
        ),
        SpendingInsight(
            type: .warning,
            title: "Spending up 23% from last week",
            subtitle: "Mostly in Entertainment category",
            value: "+23%"
        ),
        SpendingInsight(
            type: .achievement,
            title: "You saved ₹2,000 on Transport",
            subtitle: "Great job using public transit!",
            value: "₹2K saved"
        )
    ]

    ZStack {
        AdaptiveBackground(style: .primary)

        VStack(spacing: 20) {
            SpendingInsightsCard(insights: sampleInsights)

            SpendingInsightsCard(insights: [])
        }
        .padding()
    }
}

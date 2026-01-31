//
//  SpendingChartCard.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import Charts

// MARK: - Spending Chart Card (iOS 26 Stable)

/// A beautiful chart card showing spending by category using Swift Charts
struct SpendingChartCard: View {
    let data: [CategorySpending]
    let title: String
    let period: TimePeriod

    @State private var selectedCategory: CategorySpending?
    @Environment(\.colorScheme) private var colorScheme

    init(
        data: [CategorySpending],
        title: String = "Spending by Category",
        period: TimePeriod = .week
    ) {
        self.data = data
        self.title = title
        self.period = period
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView

            if data.isEmpty {
                emptyStateView
            } else {
                // Chart
                chartView

                // Legend (for small data sets)
                if data.count <= 5 {
                    legendView
                }
            }
        }
        .padding(20)
        .background {
            glassBackground
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(period.displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Selected amount (if any)
            if let selected = selectedCategory {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(selected.category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selected.formattedAmount)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(hex: selected.category.colorHex) ?? .blue)
                        .contentTransition(.numericText())
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.spring(response: 0.3), value: selectedCategory?.id)
    }

    // MARK: - Chart View

    private var chartView: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Amount", NSDecimalNumber(decimal: item.amount).doubleValue),
                y: .value("Category", item.category.name)
            )
            .foregroundStyle(
                Color(hex: item.category.colorHex)?.gradient ?? Color.blue.gradient
            )
            .cornerRadius(6)
            .annotation(position: .trailing, alignment: .leading, spacing: 8) {
                if selectedCategory?.id == item.id {
                    Text(item.formattedPercentage)
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: item.category.colorHex) ?? .blue)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleChartInteraction(at: value.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                // Keep selection for a moment then clear
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        selectedCategory = nil
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: CGFloat(min(data.count, 6) * 44))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: data)
        .sensoryFeedback(.selection, trigger: selectedCategory?.id)
    }

    // MARK: - Legend View

    private var legendView: some View {
        VStack(spacing: 8) {
            ForEach(data.prefix(5)) { item in
                HStack(spacing: 8) {
                    // Color dot
                    Circle()
                        .fill(Color(hex: item.category.colorHex) ?? .blue)
                        .frame(width: 8, height: 8)

                    // Category name
                    Text(item.category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Amount
                    Text(item.formattedAmount)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)

                    // Percentage
                    Text(item.formattedPercentage)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 40, alignment: .trailing)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        selectedCategory = item
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No spending data")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Add some transactions to see your spending breakdown")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                                .white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }

    // MARK: - Chart Interaction

    private func handleChartInteraction(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        // Find which category was tapped based on Y position
        let chartHeight = geometry.size.height
        let itemHeight = chartHeight / CGFloat(data.count)
        let index = Int(location.y / itemHeight)

        if index >= 0 && index < data.count {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = data[index]
            }
        }
    }
}

// MARK: - Mini Spending Chart

/// A compact version of the spending chart for dashboard widgets
struct MiniSpendingChart: View {
    let data: [CategorySpending]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(data.prefix(5)) { item in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: item.category.colorHex) ?? .blue)
                    .frame(width: max(4, CGFloat(item.percentage) * 2))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Pie Chart Card

/// An alternative pie chart visualization for spending
struct SpendingPieChartCard: View {
    let data: [CategorySpending]

    @State private var selectedCategory: CategorySpending?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Distribution")
                .font(.headline)

            if data.isEmpty {
                emptyStateView
            } else {
                HStack(spacing: 20) {
                    // Pie Chart
                    Chart(data) { item in
                        SectorMark(
                            angle: .value("Amount", NSDecimalNumber(decimal: item.amount).doubleValue),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(hex: item.category.colorHex) ?? .blue)
                        .cornerRadius(4)
                        .opacity(selectedCategory == nil || selectedCategory?.id == item.id ? 1 : 0.5)
                    }
                    .frame(width: 120, height: 120)

                    // Legend
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(data.prefix(4)) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: item.category.colorHex) ?? .blue)
                                    .frame(width: 8, height: 8)

                                Text(item.category.name)
                                    .font(.caption)
                                    .lineLimit(1)

                                Spacer()

                                Text(item.formattedPercentage)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyStateView: some View {
        Text("No data available")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }
}

// MARK: - Preview

#Preview("Spending Charts") {
    let sampleData: [CategorySpending] = [
        CategorySpending(
            category: SpendingCategory(name: "Food & Dining", icon: "fork.knife", colorHex: "#FF9500"),
            amount: 4500,
            transactionCount: 12,
            percentage: 35
        ),
        CategorySpending(
            category: SpendingCategory(name: "Transportation", icon: "car.fill", colorHex: "#007AFF"),
            amount: 2800,
            transactionCount: 8,
            percentage: 22
        ),
        CategorySpending(
            category: SpendingCategory(name: "Shopping", icon: "bag.fill", colorHex: "#FF2D55"),
            amount: 2200,
            transactionCount: 5,
            percentage: 17
        ),
        CategorySpending(
            category: SpendingCategory(name: "Entertainment", icon: "tv.fill", colorHex: "#AF52DE"),
            amount: 1800,
            transactionCount: 4,
            percentage: 14
        ),
        CategorySpending(
            category: SpendingCategory(name: "Bills", icon: "bolt.fill", colorHex: "#FFCC00"),
            amount: 1500,
            transactionCount: 3,
            percentage: 12
        )
    ]

    ZStack {
        AnimatedMeshGradient(colorScheme: .purple)

        ScrollView {
            VStack(spacing: 20) {
                SpendingChartCard(data: sampleData)

                SpendingPieChartCard(data: sampleData)

                SpendingChartCard(data: [], title: "Empty State")
            }
            .padding()
        }
    }
}

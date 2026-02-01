//
//  SkeletonViews.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Shimmer Effect Modifier

/// A shimmer animation effect for skeleton loading states
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Skeleton Shape

/// A basic skeleton placeholder shape
struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Balance Card Skeleton

/// A skeleton loading state for the balance card
struct BalanceCardSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            // Title
            SkeletonShape(width: 100, height: 14)

            // Main amount
            SkeletonShape(width: 180, height: 36)

            // Income and Expense
            HStack(spacing: 24) {
                // Income
                HStack(spacing: 8) {
                    SkeletonShape(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonShape(width: 50, height: 12)
                        SkeletonShape(width: 80, height: 16)
                    }
                }

                Divider()
                    .frame(height: 44)

                // Expense
                HStack(spacing: 8) {
                    SkeletonShape(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonShape(width: 50, height: 12)
                        SkeletonShape(width: 80, height: 16)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            glassBackground
        }
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
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
}

// MARK: - Quick Actions Skeleton

/// A skeleton loading state for quick action buttons (horizontal pill style)
struct QuickActionsSkeleton: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Primary action (larger)
                SkeletonShape(width: 100, height: 44)

                // Secondary actions
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonShape(width: 80, height: 40)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Chart Card Skeleton

/// A skeleton loading state for the spending chart card
struct ChartCardSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                SkeletonShape(width: 150, height: 18)
                Spacer()
            }

            // Chart bars
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    HStack(spacing: 12) {
                        SkeletonShape(width: 80, height: 14)
                        SkeletonShape(width: CGFloat(200 - index * 30), height: 24)
                    }
                }
            }
        }
        .padding(20)
        .background {
            glassBackground
        }
    }

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
}

// MARK: - Transactions Section Skeleton

/// A skeleton loading state for the recent transactions section
struct TransactionsSectionSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                SkeletonShape(width: 160, height: 18)
                Spacer()
                SkeletonShape(width: 50, height: 14)
            }

            // Transaction rows
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    transactionRowSkeleton
                }
            }
        }
        .padding(20)
        .background {
            glassBackground
        }
    }

    private var transactionRowSkeleton: some View {
        HStack(spacing: 12) {
            // Icon
            SkeletonShape(width: 40, height: 40)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                SkeletonShape(width: 100, height: 14)
                SkeletonShape(width: 60, height: 12)
            }

            Spacer()

            // Amount
            SkeletonShape(width: 80, height: 16)
        }
    }

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
}

// MARK: - Header Skeleton

/// A skeleton loading state for the dashboard header
struct HeaderSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Greeting icon
            SkeletonShape(width: 36, height: 36)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                SkeletonShape(width: 80, height: 12)
                SkeletonShape(width: 120, height: 20)
            }

            Spacer()

            // Date badge
            SkeletonShape(width: 50, height: 44)
        }
    }
}

// MARK: - Quick Stats Skeleton

/// A skeleton loading state for quick stats row
struct QuickStatsSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonShape(width: 60, height: 12)
                    SkeletonShape(width: 80, height: 16)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

// MARK: - Insights Skeleton

/// A skeleton loading state for insights card
struct InsightsSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonShape(width: 20, height: 20)
                SkeletonShape(width: 60, height: 16)
                Spacer()
            }

            // Insight row
            HStack(spacing: 12) {
                SkeletonShape(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonShape(width: nil, height: 14)
                    SkeletonShape(width: 120, height: 12)
                }
            }
        }
        .padding(16)
        .background {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.yellow.opacity(0.08))
            }
        }
    }
}

// MARK: - Full Dashboard Skeleton (2026 Modern UI)

/// A complete skeleton loading state for the entire dashboard
struct DashboardSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            // 1. Header
            HeaderSkeleton()

            // 2. Quick Actions
            QuickActionsSkeleton()

            // 3. Balance Card
            BalanceCardSkeleton()

            // 4. Quick Stats
            QuickStatsSkeleton()

            // 5. Insights
            InsightsSkeleton()

            // 6. Chart
            ChartCardSkeleton()

            // 7. Transactions
            TransactionsSectionSkeleton()
        }
    }
}

// MARK: - Preview

#Preview("Skeleton Views - Full Dashboard") {
    ZStack {
        AdaptiveBackground(style: .primary)

        ScrollView {
            DashboardSkeleton()
                .padding()
        }
    }
}

#Preview("Skeleton Views - Individual") {
    ZStack {
        AdaptiveBackground(style: .primary)

        ScrollView {
            VStack(spacing: 20) {
                HeaderSkeleton()
                QuickActionsSkeleton()
                BalanceCardSkeleton()
                QuickStatsSkeleton()
                InsightsSkeleton()
                ChartCardSkeleton()
                TransactionsSectionSkeleton()
            }
            .padding()
        }
    }
}

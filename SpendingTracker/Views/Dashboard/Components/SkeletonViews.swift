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

/// A skeleton loading state for quick action buttons
struct QuickActionsSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                quickActionSkeleton
            }
        }
    }

    private var quickActionSkeleton: some View {
        VStack(spacing: 8) {
            SkeletonShape(width: 32, height: 32)
            SkeletonShape(width: 50, height: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

// MARK: - Full Dashboard Skeleton

/// A complete skeleton loading state for the entire dashboard
struct DashboardSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                BalanceCardSkeleton()
                QuickActionsSkeleton()
                ChartCardSkeleton()
                TransactionsSectionSkeleton()
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview("Skeleton Views") {
    ZStack {
        AnimatedMeshGradient(colorScheme: .purple)

        ScrollView {
            VStack(spacing: 20) {
                BalanceCardSkeleton()
                QuickActionsSkeleton()
                ChartCardSkeleton()
                TransactionsSectionSkeleton()
            }
            .padding()
        }
    }
}

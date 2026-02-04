//
//  FamilyHubView.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//
//  Inspired by Splitwise's family/group management UI with iOS 26 Liquid Glass design

import SwiftUI

// MARK: - Family Hub View

/// The main hub for managing family budgets - shows all families user belongs to
/// Inspired by Splitwise's group list with cover photos and modern iOS design
struct FamilyHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var familyService = FamilyService()

    @State private var showCreateFamily = false
    @State private var showJoinFamily = false
    @State private var selectedFamily: FamilyBudgetDTO?
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AdaptiveBackground(style: .secondary)

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Card
                        headerCard

                        // Quick Actions
                        quickActionsSection

                        // Families List
                        if isLoading {
                            familiesLoadingSkeleton
                        } else if familyService.userFamilies.isEmpty {
                            emptyStateView
                        } else {
                            familiesSection
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await loadFamilies()
                }
            }
            .navigationTitle("Family Budgets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCreateFamily = true
                        } label: {
                            Label("Create Family", systemImage: "plus.circle")
                        }

                        Button {
                            showJoinFamily = true
                        } label: {
                            Label("Join Family", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showCreateFamily) {
                CreateFamilyView(familyService: familyService) { newFamily in
                    selectedFamily = newFamily
                }
            }
            .sheet(isPresented: $showJoinFamily) {
                JoinFamilyView(familyService: familyService) { joinedFamily in
                    selectedFamily = joinedFamily
                }
            }
            .navigationDestination(item: $selectedFamily) { family in
                FamilyDashboardView(family: family, familyService: familyService)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadFamilies()
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        GlassCard(tint: .blue) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shared Family Budgets")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Manage household finances together")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Stats Row
                if !familyService.userFamilies.isEmpty {
                    Divider()

                    HStack(spacing: 24) {
                        statItem(
                            value: "\(familyService.userFamilies.count)",
                            label: "Families",
                            icon: "house.fill"
                        )

                        statItem(
                            value: totalMembersCount,
                            label: "Members",
                            icon: "person.2.fill"
                        )
                    }
                }
            }
        }
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var totalMembersCount: String {
        // This would need actual member counts from the families
        // For now, show a placeholder
        "—"
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            quickActionButton(
                title: "Create",
                subtitle: "New Family",
                icon: "plus.circle.fill",
                color: .blue
            ) {
                showCreateFamily = true
            }

            quickActionButton(
                title: "Join",
                subtitle: "With Code",
                icon: "person.badge.plus",
                color: .green
            ) {
                showJoinFamily = true
            }
        }
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            GlassCard(cornerRadius: 16, padding: 16) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 40, height: 40)
                        .background(color.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Families Section

    private var familiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Families")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)

            LazyVStack(spacing: 12) {
                ForEach(familyService.userFamilies) { family in
                    FamilyRowCard(family: family) {
                        selectedFamily = family
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("No Family Budgets Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create a family budget to start tracking expenses together with your loved ones")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    showCreateFamily = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Family Budget")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    showJoinFamily = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Join with Invite Code")
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Loading Skeleton

    private var familiesLoadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Families")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)

            ForEach(0..<3, id: \.self) { _ in
                GlassCard {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)

                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 120, height: 16)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 80, height: 12)
                        }

                        Spacer()
                    }
                }
                .shimmering()
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadFamilies() async {
        isLoading = true
        do {
            try await familyService.fetchUserFamilies()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
}

// MARK: - Family Row Card

struct FamilyRowCard: View {
    let family: FamilyBudgetDTO
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // Random gradient colors based on family ID (consistent per family)
    private var gradientColors: [Color] {
        let colors: [[Color]] = [
            [.blue, .purple],
            [.green, .teal],
            [.orange, .red],
            [.pink, .purple],
            [.indigo, .blue],
            [.mint, .green]
        ]
        let index = abs(family.id.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        Button(action: onTap) {
            GlassCard(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    // Cover Area with Gradient
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 80)

                        // Family Icon Overlay
                        HStack {
                            Image(systemName: family.iconName)
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(12)

                            Spacer()
                        }
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16
                        )
                    )

                    // Content
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(family.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Text("Monthly: \(family.formattedMonthlyIncome)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Invite Code Badge
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(family.inviteCode)
                                .font(.caption)
                                .fontWeight(.medium)
                                .fontDesign(.monospaced)
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
            }
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

// MARK: - Placeholder Views (to be implemented)

struct FamilyDashboardView: View {
    let family: FamilyBudgetDTO
    let familyService: FamilyService

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Placeholder for family dashboard
                GlassCard(tint: .blue) {
                    VStack(spacing: 16) {
                        Image(systemName: family.iconName)
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)

                        Text(family.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Family Dashboard Coming Soon")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Divider()

                        HStack {
                            VStack {
                                Text("Monthly Income")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(family.formattedMonthlyIncome)
                                    .font(.headline)
                            }

                            Spacer()

                            VStack {
                                Text("Invite Code")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(family.inviteCode)
                                    .font(.headline)
                                    .fontDesign(.monospaced)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(family.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("Family Hub") {
    FamilyHubView()
}

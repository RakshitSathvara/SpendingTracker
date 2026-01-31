//
//  GlassSegmentedControl.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Glass Segmented Control (iOS 26 Stable)

/// A segmented control with iOS 26 Liquid Glass effect and smooth animations
struct GlassSegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let titleForOption: (T) -> String
    let iconForOption: ((T) -> String)?

    @Namespace private var animation

    init(
        selection: Binding<T>,
        options: [T],
        titleForOption: @escaping (T) -> String,
        iconForOption: ((T) -> String)? = nil
    ) {
        self._selection = selection
        self.options = options
        self.titleForOption = titleForOption
        self.iconForOption = iconForOption
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                segmentButton(for: option)
            }
        }
        .padding(4)
        .background(backgroundView)
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private func segmentButton(for option: T) -> some View {
        let isSelected = selection == option

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = option
            }
        } label: {
            segmentLabel(for: option, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func segmentLabel(for option: T, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            if let iconForOption = iconForOption {
                Image(systemName: iconForOption(option))
            }
            Text(titleForOption(option))
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .matchedGeometryEffect(id: "selection", in: animation)
            }
        }
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.5))
    }
}

// MARK: - Glass Segmented Control with CaseIterable

extension GlassSegmentedControl where T: CaseIterable, T.AllCases == [T] {
    /// Convenience initializer for CaseIterable types
    init(
        selection: Binding<T>,
        titleForOption: @escaping (T) -> String,
        iconForOption: ((T) -> String)? = nil
    ) {
        self.init(
            selection: selection,
            options: Array(T.allCases),
            titleForOption: titleForOption,
            iconForOption: iconForOption
        )
    }
}

// MARK: - Glass Tab Bar

/// A tab bar style segmented control with icons
struct GlassTabBar<T: Hashable>: View {
    @Binding var selection: T
    let tabs: [(option: T, title: String, icon: String)]

    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                tabButton(for: tab)
            }
        }
        .padding(6)
        .background(tabBarBackground)
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private func tabButton(for tab: (option: T, title: String, icon: String)) -> some View {
        let isSelected = selection == tab.option
        let iconName = isSelected ? tab.icon : tab.icon.replacingOccurrences(of: ".fill", with: "")

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = tab.option
            }
        } label: {
            tabLabel(title: tab.title, icon: iconName, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabLabel(title: String, icon: String, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .symbolEffect(.bounce, value: isSelected)

            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .matchedGeometryEffect(id: "tab", in: animation)
            }
        }
    }

    private var tabBarBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
    }
}

// MARK: - Glass Chip Selector

/// A horizontal scrollable chip selector
struct GlassChipSelector<T: Hashable>: View {
    @Binding var selection: T?
    let options: [T]
    let titleForOption: (T) -> String
    let colorForOption: ((T) -> Color)?
    let allowsDeselection: Bool

    init(
        selection: Binding<T?>,
        options: [T],
        titleForOption: @escaping (T) -> String,
        colorForOption: ((T) -> Color)? = nil,
        allowsDeselection: Bool = true
    ) {
        self._selection = selection
        self.options = options
        self.titleForOption = titleForOption
        self.colorForOption = colorForOption
        self.allowsDeselection = allowsDeselection
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    chipButton(for: option)
                }
            }
            .padding(.horizontal)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private func chipButton(for option: T) -> some View {
        let isSelected = selection == option
        let tint = colorForOption?(option) ?? .accentColor

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected && allowsDeselection {
                    selection = nil
                } else {
                    selection = option
                }
            }
        } label: {
            chipLabel(for: option, isSelected: isSelected, tint: tint)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chipLabel(for option: T, isSelected: Bool, tint: Color) -> some View {
        Text(titleForOption(option))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.ultraThinMaterial))
            }
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                }
            }
    }
}

// MARK: - Preview Types

private enum PreviewTransactionType: String, CaseIterable {
    case all = "All"
    case expense = "Expense"
    case income = "Income"
}

private enum PreviewTab: String, CaseIterable {
    case home
    case transactions
    case budget
    case settings
}

// MARK: - Preview

#Preview("Glass Segmented Controls") {
    struct PreviewWrapper: View {
        @State private var selectedType: PreviewTransactionType = .all
        @State private var selectedTab: PreviewTab = .home
        @State private var selectedCategory: String? = "Food"

        let categories = ["Food", "Transport", "Shopping", "Entertainment", "Bills"]

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Basic Segmented Control
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transaction Type")
                            .font(.headline)
                        GlassSegmentedControl(
                            selection: $selectedType,
                            titleForOption: { $0.rawValue }
                        )
                    }

                    // Tab Bar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tab Bar")
                            .font(.headline)
                        GlassTabBar(
                            selection: $selectedTab,
                            tabs: [
                                (.home, "Home", "house.fill"),
                                (.transactions, "History", "list.bullet"),
                                (.budget, "Budget", "chart.pie.fill"),
                                (.settings, "Settings", "gearshape.fill")
                            ]
                        )
                    }

                    // Chip Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categories")
                            .font(.headline)
                            .padding(.horizontal)
                        GlassChipSelector(
                            selection: $selectedCategory,
                            options: categories,
                            titleForOption: { $0 },
                            colorForOption: { category in
                                switch category {
                                case "Food": return .orange
                                case "Transport": return .blue
                                case "Shopping": return .pink
                                case "Entertainment": return .purple
                                case "Bills": return .yellow
                                default: return .accentColor
                                }
                            }
                        )
                    }

                    Spacer()
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}

//
//  DateQuickPicker.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Date Quick Picker (iOS 26 Stable)

/// A date picker with quick shortcuts (Today, Yesterday) and glass effect
struct DateQuickPicker: View {
    @Binding var selection: Date

    @State private var showDatePicker = false

    private var displayText: String {
        if Calendar.current.isDateInToday(selection) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selection) {
            return "Yesterday"
        } else {
            return selection.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selection)
    }

    var body: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: 10) {
                // Calendar Icon
                Image(systemName: "calendar")
                    .font(.body)
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(.blue.opacity(0.15))
                    }

                // Date Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if !isToday {
                        Text(selection.formatted(date: .complete, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(pickerBackground)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selection)
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selection: $selection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var pickerBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    @State private var tempDate: Date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Quick Date Shortcuts
                    HStack(spacing: 12) {
                        QuickDateButton(title: "Today", isSelected: Calendar.current.isDateInToday(tempDate)) {
                            withAnimation {
                                tempDate = Date()
                            }
                        }

                        QuickDateButton(title: "Yesterday", isSelected: Calendar.current.isDateInYesterday(tempDate)) {
                            withAnimation {
                                tempDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Divider
                    Divider()
                        .padding(.horizontal)

                    // Date Picker
                    DatePicker(
                        "Transaction Date",
                        selection: $tempDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selection = tempDate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                tempDate = selection
            }
        }
    }
}

// MARK: - Quick Date Button

struct QuickDateButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(Color(.systemGray6)))
            }
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(.systemGray4), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Inline Date Shortcuts

/// Horizontal scrollable date shortcuts for quick selection
struct DateShortcuts: View {
    @Binding var selection: Date

    private let shortcuts: [(title: String, date: Date)] = {
        let calendar = Calendar.current
        let today = Date()
        return [
            ("Today", today),
            ("Yesterday", calendar.date(byAdding: .day, value: -1, to: today) ?? today),
            ("2 days ago", calendar.date(byAdding: .day, value: -2, to: today) ?? today),
            ("3 days ago", calendar.date(byAdding: .day, value: -3, to: today) ?? today),
            ("Last week", calendar.date(byAdding: .day, value: -7, to: today) ?? today)
        ]
    }()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shortcuts, id: \.title) { shortcut in
                    DateShortcutChip(
                        title: shortcut.title,
                        isSelected: Calendar.current.isDate(selection, inSameDayAs: shortcut.date)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = shortcut.date
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Date Shortcut Chip

private struct DateShortcutChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background {
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(.ultraThinMaterial))
                }
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Date Display

/// A compact date display that can be tapped to change
struct CompactDateDisplay: View {
    @Binding var selection: Date
    @State private var showPicker = false

    private var displayText: String {
        if Calendar.current.isDateInToday(selection) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selection) {
            return "Yesterday"
        } else {
            return selection.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            DatePickerSheet(selection: $selection)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Preview

#Preview("Date Quick Picker") {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Dropdown Style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dropdown Style")
                            .font(.headline)
                        DateQuickPicker(selection: $selectedDate)
                    }
                    .padding()

                    // Shortcuts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date Shortcuts")
                            .font(.headline)
                            .padding(.horizontal)
                        DateShortcuts(selection: $selectedDate)
                    }

                    // Compact
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compact Style")
                            .font(.headline)
                        CompactDateDisplay(selection: $selectedDate)
                    }
                    .padding()
                }
            }
        }
    }

    return PreviewWrapper()
}

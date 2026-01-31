//
//  PersonaSelectionRow.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Persona Selection Row (iOS 26 Stable)

/// A beautiful persona selection component with Liquid Glass design
struct PersonaSelectionRow: View {

    // MARK: - Properties

    @Binding var selectedPersona: UserPersona
    var showLabel: Bool = true

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showLabel {
                Text("I am a...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(UserPersona.allCases, id: \.self) { persona in
                    PersonaButton(
                        persona: persona,
                        isSelected: selectedPersona == persona
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPersona = persona
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPersona)
    }
}

// MARK: - Persona Button

/// Individual persona selection button with glass effect
struct PersonaButton: View {

    // MARK: - Properties

    let persona: UserPersona
    let isSelected: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: persona.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected
                            ? AnyShapeStyle(persona.color.gradient)
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .clipShape(Circle())
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(.white.opacity(0.3), lineWidth: 2)
                        }
                    }

                // Label
                Text(persona.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? persona.color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? persona.color.opacity(0.1) : .clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? persona.color.opacity(0.5) : .clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(persona.displayName) persona")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Compact Persona Selector

/// A more compact version for use in forms
struct CompactPersonaSelector: View {

    // MARK: - Properties

    @Binding var selectedPersona: UserPersona

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            ForEach(UserPersona.allCases, id: \.self) { persona in
                CompactPersonaChip(
                    persona: persona,
                    isSelected: selectedPersona == persona
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPersona = persona
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPersona)
    }
}

// MARK: - Compact Persona Chip

/// Small chip version of persona selection
struct CompactPersonaChip: View {

    // MARK: - Properties

    let persona: UserPersona
    let isSelected: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: persona.icon)
                    .font(.caption)

                Text(persona.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? persona.color.opacity(0.2) : .ultraThinMaterial)
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? persona.color : .clear,
                        lineWidth: 1.5
                    )
            }
            .foregroundStyle(isSelected ? persona.color : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(persona.displayName) persona")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Persona Description Card

/// Shows detailed description for selected persona
struct PersonaDescriptionCard: View {

    // MARK: - Properties

    let persona: UserPersona

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: persona.icon)
                .font(.title2)
                .foregroundStyle(persona.color)
                .frame(width: 44, height: 44)
                .background(persona.color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(persona.displayName)
                    .font(.headline)

                Text(persona.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(persona.color)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - User Persona Extension (UI Properties)

extension UserPersona {
    /// Color associated with the persona for UI display
    var color: Color {
        switch self {
        case .student:
            return .blue
        case .professional:
            return .purple
        case .family:
            return .green
        }
    }
}

// MARK: - Preview

#Preview("Persona Selection Row") {
    VStack(spacing: 24) {
        PersonaSelectionRow(selectedPersona: .constant(.professional))

        CompactPersonaSelector(selectedPersona: .constant(.student))

        PersonaDescriptionCard(persona: .family)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

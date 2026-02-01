//
//  DashboardHeader.swift
//  SpendingTracker
//
//  Simple personalized greeting header with time-based context
//

import SwiftUI

// MARK: - Dashboard Header (2026 Modern UI)

/// Personalized greeting header that creates emotional connection with user
struct DashboardHeader: View {
    let userName: String?

    @Environment(\.colorScheme) private var colorScheme
    @State private var currentTime = Date()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private var greetingIcon: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 5..<12: return "sun.rise.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    private var displayName: String {
        if let name = userName, !name.isEmpty {
            return name.components(separatedBy: " ").first ?? name
        }
        return "there"
    }

    private var greetingIconColor: Color {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 5..<12: return .orange
        case 12..<17: return .yellow
        case 17..<21: return .orange
        default: return .indigo
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Greeting Icon
            Image(systemName: greetingIcon)
                .font(.title2)
                .foregroundStyle(greetingIconColor)

            // Greeting Text
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting),")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(displayName)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Date Badge
            dateBadge
        }
    }

    // MARK: - Date Badge

    private var dateBadge: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(currentTime, format: .dateTime.weekday(.abbreviated))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(currentTime, format: .dateTime.day())
                .font(.title3.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.1))
            }
        }
    }
}

// MARK: - Preview

#Preview("Dashboard Header") {
    ZStack {
        AdaptiveBackground(style: .primary)

        VStack(spacing: 20) {
            DashboardHeader(userName: "Rakshit")
            DashboardHeader(userName: "Alex")
            DashboardHeader(userName: nil)
        }
        .padding()
    }
}

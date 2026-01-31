//
//  NumberPad.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Number Pad (iOS 26 Stable)

/// A calculator-style number pad with glass effect and haptic feedback
struct NumberPad: View {
    @Binding var value: String
    let currencyCode: String
    let maxDigits: Int
    let maxDecimalPlaces: Int
    let onValueChange: ((Decimal) -> Void)?

    @State private var lastTappedButton: String?

    private let buttons: [[NumberPadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.decimal, .digit("0"), .backspace]
    ]

    init(
        value: Binding<String>,
        currencyCode: String = "INR",
        maxDigits: Int = 10,
        maxDecimalPlaces: Int = 2,
        onValueChange: ((Decimal) -> Void)? = nil
    ) {
        self._value = value
        self.currencyCode = currencyCode
        self.maxDigits = maxDigits
        self.maxDecimalPlaces = maxDecimalPlaces
        self.onValueChange = onValueChange
    }

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(buttons, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        NumberPadButton(
                            key: key,
                            isPressed: lastTappedButton == key.displayValue
                        ) {
                            handleKeyPress(key)
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lastTappedButton)
    }

    // MARK: - Key Press Handling

    private func handleKeyPress(_ key: NumberPadKey) {
        lastTappedButton = key.displayValue

        // Reset visual feedback after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            lastTappedButton = nil
        }

        switch key {
        case .digit(let digit):
            handleDigitInput(digit)
        case .decimal:
            handleDecimalInput()
        case .backspace:
            handleBackspace()
        }

        // Notify value change
        if let decimal = Decimal(string: value) {
            onValueChange?(decimal)
        }
    }

    private func handleDigitInput(_ digit: String) {
        // Don't allow leading zeros (except for "0.")
        if value == "0" && digit != "0" {
            value = digit
            return
        }

        // Check max digits limit
        let digitsOnly = value.replacingOccurrences(of: ".", with: "")
        if digitsOnly.count >= maxDigits {
            return
        }

        // Check decimal places limit
        if let decimalIndex = value.firstIndex(of: ".") {
            let decimalPlaces = value.distance(from: decimalIndex, to: value.endIndex) - 1
            if decimalPlaces >= maxDecimalPlaces {
                return
            }
        }

        // Don't add more zeros if value is just "0"
        if value == "0" && digit == "0" {
            return
        }

        value += digit
    }

    private func handleDecimalInput() {
        // Only add decimal if not already present
        if !value.contains(".") {
            value += "."
        }
    }

    private func handleBackspace() {
        if value.count > 1 {
            value.removeLast()
        } else {
            value = "0"
        }
    }
}

// MARK: - Number Pad Key

enum NumberPadKey: Hashable {
    case digit(String)
    case decimal
    case backspace

    var displayValue: String {
        switch self {
        case .digit(let value): return value
        case .decimal: return "."
        case .backspace: return "⌫"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .digit(let value): return value
        case .decimal: return "Decimal point"
        case .backspace: return "Delete"
        }
    }
}

// MARK: - Number Pad Button

struct NumberPadButton: View {
    let key: NumberPadKey
    let isPressed: Bool
    let action: () -> Void

    @State private var isInternalPressed = false

    var body: some View {
        Button(action: action) {
            Group {
                switch key {
                case .digit(let value):
                    Text(value)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                case .decimal:
                    Text(".")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                case .backspace:
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .medium))
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isInternalPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.accessibilityLabel)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isInternalPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isInternalPressed = false
                    }
                }
        )
    }

    @ViewBuilder
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isInternalPressed ? Color.primary.opacity(0.1) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
    }
}

// MARK: - Compact Number Pad

/// A more compact number pad for smaller screens
struct CompactNumberPad: View {
    @Binding var value: String
    let onValueChange: ((Decimal) -> Void)?

    private let buttons: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    init(value: Binding<String>, onValueChange: ((Decimal) -> Void)? = nil) {
        self._value = value
        self.onValueChange = onValueChange
    }

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(buttons, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { button in
                        CompactNumberPadButton(title: button) {
                            handleTap(button)
                        }
                    }
                }
            }
        }
    }

    private func handleTap(_ button: String) {
        switch button {
        case "⌫":
            if value.count > 1 {
                value.removeLast()
            } else {
                value = "0"
            }
        case ".":
            if !value.contains(".") {
                value += "."
            }
        default:
            if value == "0" {
                value = button
            } else {
                value += button
            }
        }

        if let decimal = Decimal(string: value) {
            onValueChange?(decimal)
        }
    }
}

// MARK: - Compact Number Pad Button

private struct CompactNumberPadButton: View {
    let title: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Group {
                if title == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18, weight: .medium))
                } else {
                    Text(title)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.08)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.08)) { isPressed = false }
                }
        )
    }
}

// MARK: - Preview

#Preview("Number Pad") {
    struct PreviewWrapper: View {
        @State private var value = "0"

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Amount Display
                    Text("₹\(value)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    // Number Pad
                    NumberPad(value: $value) { decimal in
                        print("Value changed: \(decimal)")
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Compact Number Pad") {
    struct PreviewWrapper: View {
        @State private var value = "0"

        var body: some View {
            ZStack {
                Color.gray.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("₹\(value)")
                        .font(.title)
                        .fontWeight(.bold)

                    CompactNumberPad(value: $value)
                        .padding()
                }
            }
        }
    }

    return PreviewWrapper()
}

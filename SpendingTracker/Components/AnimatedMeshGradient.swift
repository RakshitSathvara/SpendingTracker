//
//  AnimatedMeshGradient.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Animated Mesh Gradient (iOS 26 Stable)

/// An animated mesh gradient background for auth screens and hero sections
struct AnimatedMeshGradient: View {
    @State private var phase: CGFloat = 0
    let colorScheme: MeshGradientColorScheme

    init(colorScheme: MeshGradientColorScheme = .purple) {
        self.colorScheme = colorScheme
    }

    private var animatedPoints: [SIMD2<Float>] {
        let offset = Float(phase) * 0.1
        return [
            SIMD2(0, 0), SIMD2(0.5, 0 + offset), SIMD2(1, 0),
            SIMD2(0 + offset, 0.5), SIMD2(0.5, 0.5), SIMD2(1 - offset, 0.5),
            SIMD2(0, 1), SIMD2(0.5, 1 - offset), SIMD2(1, 1)
        ]
    }

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: animatedPoints,
            colors: colorScheme.colors
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }
}

// MARK: - Mesh Gradient Color Schemes

enum MeshGradientColorScheme {
    case purple
    case blue
    case green
    case orange
    case pink
    case dark
    case custom([Color])

    var colors: [Color] {
        switch self {
        case .purple:
            return [
                .blue.opacity(0.3), .purple.opacity(0.4), .blue.opacity(0.3),
                .cyan.opacity(0.3), .purple.opacity(0.5), .pink.opacity(0.3),
                .blue.opacity(0.3), .cyan.opacity(0.4), .purple.opacity(0.3)
            ]
        case .blue:
            return [
                .blue.opacity(0.4), .cyan.opacity(0.3), .blue.opacity(0.3),
                .cyan.opacity(0.4), .blue.opacity(0.5), .teal.opacity(0.3),
                .blue.opacity(0.3), .cyan.opacity(0.3), .blue.opacity(0.4)
            ]
        case .green:
            return [
                .green.opacity(0.3), .teal.opacity(0.4), .green.opacity(0.3),
                .mint.opacity(0.3), .green.opacity(0.5), .cyan.opacity(0.3),
                .teal.opacity(0.3), .green.opacity(0.4), .mint.opacity(0.3)
            ]
        case .orange:
            return [
                .orange.opacity(0.3), .red.opacity(0.3), .orange.opacity(0.4),
                .yellow.opacity(0.3), .orange.opacity(0.5), .red.opacity(0.3),
                .orange.opacity(0.3), .yellow.opacity(0.3), .orange.opacity(0.3)
            ]
        case .pink:
            return [
                .pink.opacity(0.3), .purple.opacity(0.3), .pink.opacity(0.4),
                .red.opacity(0.3), .pink.opacity(0.5), .purple.opacity(0.3),
                .pink.opacity(0.3), .red.opacity(0.3), .pink.opacity(0.3)
            ]
        case .dark:
            return [
                .black, .gray.opacity(0.3), .black,
                .gray.opacity(0.2), .black, .gray.opacity(0.2),
                .black, .gray.opacity(0.3), .black
            ]
        case .custom(let colors):
            // Ensure we have exactly 9 colors for the 3x3 mesh
            guard colors.count >= 9 else {
                return Array(repeating: colors.first ?? .blue, count: 9)
            }
            return Array(colors.prefix(9))
        }
    }
}

// MARK: - Static Gradient Background

/// A static gradient background for screens that don't need animation
struct StaticGradientBackground: View {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint

    init(
        colors: [Color] = [.blue.opacity(0.3), .purple.opacity(0.3)],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        )
        .ignoresSafeArea()
    }
}

// MARK: - Radial Gradient Background

/// A radial gradient background centered on a focal point
struct RadialGradientBackground: View {
    let centerColor: Color
    let edgeColor: Color
    let center: UnitPoint

    init(
        centerColor: Color = .purple.opacity(0.4),
        edgeColor: Color = .blue.opacity(0.2),
        center: UnitPoint = .center
    ) {
        self.centerColor = centerColor
        self.edgeColor = edgeColor
        self.center = center
    }

    var body: some View {
        RadialGradient(
            colors: [centerColor, edgeColor],
            center: center,
            startRadius: 0,
            endRadius: 500
        )
        .ignoresSafeArea()
    }
}

// MARK: - Animated Orbs Background

/// An animated background with floating orbs
struct AnimatedOrbsBackground: View {
    @State private var animate = false

    let orbCount: Int
    let colors: [Color]

    init(orbCount: Int = 5, colors: [Color] = [.blue, .purple, .pink, .cyan]) {
        self.orbCount = orbCount
        self.colors = colors
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [.black, Color(white: 0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Animated orbs
                ForEach(0..<orbCount, id: \.self) { index in
                    let color = colors[index % colors.count]
                    let size = CGFloat.random(in: 150...300)
                    let xOffset = CGFloat.random(in: -100...geometry.size.width)
                    let yOffset = CGFloat.random(in: -100...geometry.size.height)

                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: size, height: size)
                        .blur(radius: 60)
                        .offset(
                            x: animate ? xOffset + 50 : xOffset - 50,
                            y: animate ? yOffset + 30 : yOffset - 30
                        )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Animated Backgrounds") {
    TabView {
        AnimatedMeshGradient(colorScheme: .purple)
            .overlay {
                Text("Purple Mesh")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            .tabItem { Text("Purple") }

        AnimatedMeshGradient(colorScheme: .blue)
            .overlay {
                Text("Blue Mesh")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            .tabItem { Text("Blue") }

        AnimatedMeshGradient(colorScheme: .green)
            .overlay {
                Text("Green Mesh")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            .tabItem { Text("Green") }

        AnimatedOrbsBackground()
            .overlay {
                Text("Animated Orbs")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            .tabItem { Text("Orbs") }
    }
}

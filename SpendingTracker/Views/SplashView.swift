//
//  SplashView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Splash View (iOS 26 Stable)

/// Modern animated splash screen with glassmorphism and dynamic effects
struct SplashView: View {

    // MARK: - Animation States

    @State private var logoScale: CGFloat = 0.3
    @State private var logoRotation: Double = -30
    @State private var logoOpacity: CGFloat = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: CGFloat = 0
    @State private var outerRingRotation: Double = 0
    @State private var innerRingRotation: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: CGFloat = 0
    @State private var taglineOffset: CGFloat = 20
    @State private var taglineOpacity: CGFloat = 0
    @State private var loadingOpacity: CGFloat = 0
    @State private var floatingOffset: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -200

    // MARK: - Body

    var body: some View {
        ZStack {
            // Animated mesh gradient background
            AuthBackground(colorTheme: .purple)

            // Floating particles
            FloatingParticlesView()

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Animated Logo Section
                logoSection
                    .padding(.bottom, 32)

                // App Title
                titleSection

                Spacer()

                // Modern loading indicator
                modernLoadingIndicator
                    .padding(.bottom, 80)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        ZStack {
            // Outer rotating ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .purple.opacity(0.8),
                            .blue.opacity(0.4),
                            .cyan.opacity(0.6),
                            .purple.opacity(0.8)
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(outerRingRotation))
                .opacity(ringOpacity)

            // Inner counter-rotating ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .cyan.opacity(0.6),
                            .white.opacity(0.2),
                            .purple.opacity(0.4),
                            .cyan.opacity(0.6)
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(innerRingRotation))
                .opacity(ringOpacity * 0.7)

            // Pulsing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.purple.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale)
                .opacity(ringOpacity * 0.5)

            // Glass container
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 120, height: 120)
                .overlay {
                    // Glass border with shimmer
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .white.opacity(0.1),
                                    .white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .overlay {
                            // Shimmer effect
                            Circle()
                                .stroke(lineWidth: 1.5)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.8), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: shimmerOffset)
                                .mask(Circle().stroke(lineWidth: 1.5))
                        }
                }
                .shadow(color: .purple.opacity(0.4), radius: 30, x: 0, y: 15)
                .shadow(color: .blue.opacity(0.2), radius: 20, x: 0, y: 10)

            // Animated icon
            AnimatedCurrencyIcon()
                .scaleEffect(logoScale)
                .rotationEffect(.degrees(logoRotation))
                .opacity(logoOpacity)
        }
        .offset(y: floatingOffset)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 12) {
            // App name with gradient
            Text("SpendingTracker")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                .offset(y: titleOffset)
                .opacity(titleOpacity)

            // Tagline with typing effect style
            Text("Smart finances, simplified")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .offset(y: taglineOffset)
                .opacity(taglineOpacity)
        }
    }

    // MARK: - Modern Loading Indicator

    private var modernLoadingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                LoadingDot(index: index)
            }
        }
        .opacity(loadingOpacity)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Ring animations
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }

        // Continuous ring rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            outerRingRotation = 360
        }
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            innerRingRotation = -360
        }

        // Logo entrance with spring
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0
            logoRotation = 0
            logoOpacity = 1.0
        }

        // Title slide up
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.4)) {
            titleOffset = 0
            titleOpacity = 1.0
        }

        // Tagline slide up
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.55)) {
            taglineOffset = 0
            taglineOpacity = 1.0
        }

        // Loading indicator fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            loadingOpacity = 1.0
        }

        // Floating animation
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            floatingOffset = -8
        }

        // Shimmer animation
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false).delay(1)) {
            shimmerOffset = 200
        }
    }
}

// MARK: - Animated Currency Icon

struct AnimatedCurrencyIcon: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background glow
            Image(systemName: "indianrupeesign")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.purple.opacity(0.5))
                .blur(radius: 8)
                .scaleEffect(isAnimating ? 1.1 : 1.0)

            // Main icon
            Image(systemName: "indianrupeesign")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.4, blue: 1.0),
                            Color(red: 0.4, green: 0.6, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Loading Dot

struct LoadingDot: View {
    let index: Int
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.9), .white.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .opacity(isAnimating ? 1.0 : 0.3)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.15)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Floating Particles View

struct FloatingParticlesView: View {
    let particleCount = 15

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<particleCount, id: \.self) { index in
                FloatingParticle(
                    size: geometry.size,
                    index: index
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct FloatingParticle: View {
    let size: CGSize
    let index: Int

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0

    private var particleSize: CGFloat {
        CGFloat.random(in: 4...12)
    }

    private var particleColor: Color {
        let colors: [Color] = [.white, .purple, .cyan, .blue]
        return colors[index % 4].opacity(0.4)
    }

    var body: some View {
        Circle()
            .fill(particleColor)
            .frame(width: particleSize, height: particleSize)
            .blur(radius: 1)
            .position(position)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                // Initial position
                position = CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )

                // Animate in
                withAnimation(.easeOut(duration: Double.random(in: 1...2)).delay(Double(index) * 0.1)) {
                    opacity = Double.random(in: 0.3...0.7)
                    scale = 1.0
                }

                // Floating animation
                withAnimation(
                    .easeInOut(duration: Double.random(in: 4...8))
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.2)
                ) {
                    position = CGPoint(
                        x: position.x + CGFloat.random(in: -50...50),
                        y: position.y + CGFloat.random(in: -80...80)
                    )
                }
            }
    }
}

// MARK: - Preview

#Preview {
    SplashView()
}

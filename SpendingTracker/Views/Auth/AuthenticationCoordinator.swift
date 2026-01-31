//
//  AuthenticationCoordinator.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Authentication Coordinator (iOS 26 Stable)

/// Coordinates the authentication flow with smooth transitions between login and sign up
struct AuthenticationCoordinator: View {

    // MARK: - Environment

    @Environment(AuthenticationService.self) private var authService

    // MARK: - State

    @State private var showingSignUp = false

    // MARK: - Body

    var body: some View {
        ZStack {
            if showingSignUp {
                SignUpView(showingSignUp: $showingSignUp)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                LoginView(showingSignUp: $showingSignUp)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showingSignUp)
    }
}

// MARK: - Preview

#Preview {
    AuthenticationCoordinator()
        .environment(AuthenticationService())
}

//
//  SpendingTrackerApp.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

// MARK: - App Delegate for Firebase Configuration

/// AppDelegate configures Firebase before any other initialization happens
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Configure Firestore settings for cloud-only mode
        configureFirestoreSettings()

        return true
    }

    /// Configure Firestore settings for cloud-only approach
    /// Using memory cache since app is cloud-first
    private func configureFirestoreSettings() {
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
    }
}

@main
struct SpendingTrackerApp: App {

    // MARK: - App Delegate (Firebase must be configured first)

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // MARK: - Theme Preference

    @AppStorage("selectedTheme") private var selectedTheme: String = "system"

    /// Computed color scheme based on user preference
    private var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System default
        }
    }

    // MARK: - Services (iOS 26 @Observable)

    @State private var authService = AuthenticationService()

    // MARK: - Sync Services (Singletons with @Observable)

    private var networkMonitor = NetworkMonitor.shared

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(networkMonitor)
                .preferredColorScheme(preferredColorScheme)
        }
    }
}

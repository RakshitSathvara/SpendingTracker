//
//  SpendingTrackerApp.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData
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

        // Configure Firestore settings BEFORE any Firestore operations
        // This must be done immediately after FirebaseApp.configure() and before any other Firestore access
        configureFirestoreSettings()

        // Register background tasks for sync
        BackgroundSyncManager.shared.registerBackgroundTasks()

        return true
    }

    /// Configure Firestore settings for online-first approach
    /// Disabling offline persistence to ensure cross-device sync works correctly
    /// Must be called before any other Firestore operations
    private func configureFirestoreSettings() {
        let settings = FirestoreSettings()
        // Disable offline persistence to ensure fresh data from server
        // SwiftData handles local storage, Firestore is the cloud source of truth
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
    }
}

@main
struct SpendingTrackerApp: App {

    // MARK: - App Delegate (Firebase must be configured first)

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

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
    @State private var firestoreService = FirestoreService()

    // MARK: - Sync Services (Singletons with @Observable)

    private var syncService = SyncService.shared
    private var networkMonitor = NetworkMonitor.shared
    private var backgroundSyncManager = BackgroundSyncManager.shared

    // MARK: - SwiftData Container (iOS 26 Stable)

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Account.self,
            Budget.self,
            UserProfile.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // Using Firestore instead of CloudKit
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(firestoreService)
                .environment(syncService)
                .environment(networkMonitor)
                .preferredColorScheme(preferredColorScheme)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active - check for sync
            backgroundSyncManager.sceneDidBecomeActive()
            syncService.startSync()
            networkMonitor.startMonitoring()

        case .inactive:
            // App is transitioning
            backgroundSyncManager.sceneWillResignActive()

        case .background:
            // App entered background - schedule background sync
            backgroundSyncManager.sceneDidEnterBackground()
            syncService.stopSync()

        @unknown default:
            break
        }
    }
}

// MARK: - Preview Support

extension ModelContainer {
    /// Creates an in-memory container for SwiftUI previews
    static var preview: ModelContainer {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Account.self,
            Budget.self,
            UserProfile.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])

            // Add sample data for previews
            Task { @MainActor in
                let context = container.mainContext

                // Add default categories
                for category in Category.allDefaultCategories {
                    context.insert(category)
                }

                // Add default accounts
                for account in Account.defaultAccounts {
                    context.insert(account)
                }

                // Add sample transactions
                let sampleCategories = try? context.fetch(FetchDescriptor<Category>())
                let sampleAccounts = try? context.fetch(FetchDescriptor<Account>())

                if let foodCategory = sampleCategories?.first(where: { $0.name == "Food & Dining" }),
                   let cashAccount = sampleAccounts?.first(where: { $0.name == "Cash" }) {
                    let transaction = Transaction(
                        amount: 250.00,
                        note: "Lunch at restaurant",
                        date: Date(),
                        type: .expense,
                        merchantName: "Local Restaurant",
                        category: foodCategory,
                        account: cashAccount
                    )
                    context.insert(transaction)
                }

                try? context.save()
            }

            return container
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }
}

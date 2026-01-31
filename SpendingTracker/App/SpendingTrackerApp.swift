//
//  SpendingTrackerApp.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct SpendingTrackerApp: App {
    
    // MARK: - Firebase Initialization
    init() {
        FirebaseApp.configure()
    }
    
    // MARK: - SwiftData Container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            PaymentMethod.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

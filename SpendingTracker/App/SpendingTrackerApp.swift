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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
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

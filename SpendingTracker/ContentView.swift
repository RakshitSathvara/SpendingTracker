//
//  ContentView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Content View (iOS 26 Stable)

struct ContentView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext

    @State private var showSplash = true
    @State private var minimumSplashTimeElapsed = false

    /// Minimum time to show splash (for brand feel)
    private let minimumSplashDuration: Double = 1.8

    var body: some View {
        Group {
            if showSplash {
                // Show splash screen exclusively during initialization
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            } else {
                // Main content (auth or main view)
                Group {
                    if authService.isAuthenticated {
                        MainTabView()
                            .transition(.asymmetric(
                                insertion: .push(from: .trailing).combined(with: .opacity),
                                removal: .push(from: .leading).combined(with: .opacity)
                            ))
                    } else {
                        AuthenticationCoordinator()
                            .transition(.asymmetric(
                                insertion: .push(from: .leading).combined(with: .opacity),
                                removal: .push(from: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .animation(.easeInOut(duration: 0.4), value: authService.isAuthenticated)
        .onAppear {
            // Configure auth service after Firebase is ready
            authService.configure()

            // Start minimum splash timer
            Task {
                try? await Task.sleep(for: .seconds(minimumSplashDuration))
                await MainActor.run {
                    minimumSplashTimeElapsed = true
                    checkAndDismissSplash()
                }
            }
        }
        .onChange(of: authService.isConfigured) { _, isConfigured in
            if isConfigured {
                checkAndDismissSplash()
            }
        }
    }

    /// Dismisses splash only when both conditions are met:
    /// 1. Auth service is configured
    /// 2. Minimum splash time has elapsed
    private func checkAndDismissSplash() {
        guard authService.isConfigured && minimumSplashTimeElapsed else { return }

        withAnimation(.easeOut(duration: 0.5)) {
            showSplash = false
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var selectedTab = 0
    @State private var hasInitializedData = false
    @State private var isCloudSyncing = false
    @State private var cloudSyncError: String?
    @State private var showSyncError = false

    // Cloud sync service for downloading data from Firestore
    private var cloudSyncService = CloudDataSyncService.shared

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                TransactionListView()
                    .tabItem {
                        Label("Transactions", systemImage: "list.bullet")
                    }
                    .tag(1)

                BudgetListView()
                    .tabItem {
                        Label("Budget", systemImage: "chart.pie.fill")
                    }
                    .tag(2)

                FamilyHubView()
                    .tabItem {
                        Label("Family", systemImage: "figure.2.and.child.holdinghands")
                    }
                    .tag(3)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }

            // Cloud sync overlay
            if isCloudSyncing {
                CloudSyncOverlay(message: cloudSyncService.progressMessage)
            }
        }
        .onAppear {
            // First, sync data from cloud (online-first approach)
            // This ensures data from other devices is available
            Task {
                await performCloudSync()
            }
        }
        .alert("Sync Error", isPresented: $showSyncError) {
            Button("OK") { }
            Button("Retry") {
                Task {
                    await performCloudSync()
                }
            }
        } message: {
            Text(cloudSyncError ?? "Failed to sync data from cloud")
        }
    }

    /// Perform cloud sync to download data from Firestore
    private func performCloudSync() async {
        // Skip if already syncing or already completed initial sync
        guard !cloudSyncService.isSyncing else { return }

        isCloudSyncing = true

        do {
            // Download data from Firestore and sync to SwiftData
            try await cloudSyncService.downloadAndSyncAllData(to: modelContext)

            // After cloud sync, initialize any missing default data
            if !hasInitializedData {
                DataInitializer.shared.initializeDefaultDataIfNeeded(context: modelContext)
                hasInitializedData = true
            }

            isCloudSyncing = false

        } catch {
            isCloudSyncing = false

            // Only show error if it's not a network issue on first launch
            // Users can still use the app with local data
            if !hasInitializedData {
                // Initialize default data even if cloud sync fails
                DataInitializer.shared.initializeDefaultDataIfNeeded(context: modelContext)
                hasInitializedData = true
            }

            // Store error but don't always show alert (might be offline)
            cloudSyncError = error.localizedDescription
            print("⚠️ Cloud sync error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Cloud Sync Overlay

struct CloudSyncOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    let transactions: [Transaction]
    @Environment(AuthenticationService.self) private var authService
    @State private var isViewReady = false

    private var totalExpenses: Decimal {
        transactions
            .filter { $0.isExpense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var totalIncome: Decimal {
        transactions
            .filter { $0.isIncome }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Card
                    welcomeCard

                    // Summary Cards
                    summaryCards

                    // Recent Transactions
                    recentTransactionsSection
                }
                .padding()
                .opacity(isViewReady ? 1 : 0)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Small delay to ensure navigation bar renders correctly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isViewReady = true
                    }
                }
            }
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back,")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(authService.displayName ?? "User")
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            GlassBackground(cornerRadius: 16)
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "Expenses",
                amount: totalExpenses,
                color: .red,
                icon: "arrow.up.circle.fill"
            )

            SummaryCard(
                title: "Income",
                amount: totalIncome,
                color: .green,
                icon: "arrow.down.circle.fill"
            )
        }
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    TransactionListView()
                }
                .font(.subheadline)
            }

            if transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "creditcard.fill",
                    description: Text("Add your first transaction to start tracking.")
                )
                .frame(height: 200)
            } else {
                ForEach(transactions.prefix(5)) { transaction in
                    TransactionRowView(transaction: transaction)
                }
            }
        }
        .padding()
        .background {
            GlassBackground(cornerRadius: 16)
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    let icon: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(formatCurrency(amount))
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            GlassBackground(cornerRadius: 12)
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            // Category Icon
            if let category = transaction.category {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(category.color)
                    .frame(width: 40, height: 40)
                    .background(category.color.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Image(systemName: transaction.isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(transaction.isExpense ? .red : .green)
                    .frame(width: 40, height: 40)
                    .background((transaction.isExpense ? Color.red : Color.green).opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displayTitle)
                    .font(.headline)
                Text(transaction.date, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(transaction.formattedAmount)
                .font(.headline)
                .foregroundStyle(transaction.isExpense ? .red : .green)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    let transaction: Transaction

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Amount", value: transaction.formattedAmount)
                LabeledContent("Type", value: transaction.type.rawValue)
                LabeledContent("Date") {
                    Text(transaction.date, format: Date.FormatStyle(date: .long, time: .shortened))
                }
                if let merchant = transaction.merchantName, !merchant.isEmpty {
                    LabeledContent("Merchant", value: merchant)
                }
            }

            if let category = transaction.category {
                Section("Category") {
                    Label(category.name, systemImage: category.icon)
                        .foregroundStyle(category.color)
                }
            }

            if let account = transaction.account {
                Section("Account") {
                    Label(account.name, systemImage: account.icon)
                        .foregroundStyle(account.color)
                }
            }

            if !transaction.note.isEmpty {
                Section("Notes") {
                    Text(transaction.note)
                }
            }
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(SyncService.self) private var syncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme

    // Cloud sync service for manual sync
    private var cloudSyncService = CloudDataSyncService.shared

    // Theme preference stored in UserDefaults
    @AppStorage("selectedTheme") private var selectedTheme: String = "system"

    @State private var isCloudSyncing = false

    // Computed property for display
    private var themeOptions: [(id: String, title: String, icon: String)] {
        [
            ("system", "System", "iphone"),
            ("light", "Light", "sun.max.fill"),
            ("dark", "Dark", "moon.fill")
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section {
                    ForEach(themeOptions, id: \.id) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTheme = option.id
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.icon)
                                    .font(.title3)
                                    .foregroundStyle(selectedTheme == option.id ? .blue : .secondary)
                                    .frame(width: 28)

                                Text(option.title)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedTheme == option.id {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .sensoryFeedback(.selection, trigger: selectedTheme)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how the app looks. System follows your device settings.")
                }

                // Data Management Section
                Section("Manage Data") {
                    NavigationLink {
                        CategoryListView()
                            .environment(syncService)
                    } label: {
                        SettingsRow(
                            title: "Categories",
                            subtitle: "Manage expense & income categories",
                            icon: "tag.fill",
                            color: .purple
                        )
                    }

                    NavigationLink {
                        AccountListView()
                            .environment(syncService)
                    } label: {
                        SettingsRow(
                            title: "Accounts",
                            subtitle: "Manage your accounts",
                            icon: "creditcard.fill",
                            color: .blue
                        )
                    }
                }

                // User Account Section
                Section("Account") {
                    if let email = authService.email {
                        LabeledContent("Email", value: email)
                    }
                    if let name = authService.displayName {
                        LabeledContent("Name", value: name)
                    }
                }

                // Sync Status Section
                Section("Sync") {
                    HStack {
                        Image(systemName: syncService.state.icon)
                            .foregroundStyle(syncService.isSyncing ? .blue : .green)
                        Text(syncService.state.displayText)
                        Spacer()
                        if syncService.pendingChangesCount > 0 {
                            Text("\(syncService.pendingChangesCount) pending")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let lastSync = syncService.lastSyncDate {
                        LabeledContent("Last Sync") {
                            Text(lastSync, format: .relative(presentation: .named))
                        }
                    }

                    // Cloud sync button
                    Button {
                        Task {
                            isCloudSyncing = true
                            do {
                                try await cloudSyncService.forceRefresh(to: modelContext)
                            } catch {
                                print("Cloud sync error: \(error)")
                            }
                            isCloudSyncing = false
                        }
                    } label: {
                        HStack {
                            if isCloudSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            }
                            Text(isCloudSyncing ? "Syncing..." : "Sync from Cloud")
                        }
                    }
                    .disabled(isCloudSyncing || cloudSyncService.isSyncing)
                }

                // Sign Out Section
                Section {
                    Button("Sign Out", role: .destructive) {
                        try? authService.signOut()
                    }
                }

                // Delete Account Section
                Section {
                    Button("Delete Account", role: .destructive) {
                        Task {
                            try? await authService.deleteAccount()
                        }
                    }
                } footer: {
                    Text("This will permanently delete your account and all associated data.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AuthenticationService())
        .modelContainer(.preview)
}

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

    var body: some View {
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
        .animation(.easeInOut(duration: 0.4), value: authService.isAuthenticated)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    var body: some View {
        TabView {
            HomeView(transactions: transactions)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TransactionListView(transactions: transactions)
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }

            Text("Add")
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }

            Text("Budget")
                .tabItem {
                    Label("Budget", systemImage: "chart.pie.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    let transactions: [Transaction]
    @Environment(AuthenticationService.self) private var authService

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
            }
            .navigationTitle("Dashboard")
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    TransactionListView(transactions: transactions)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    let icon: String

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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

// MARK: - Transaction List View

struct TransactionListView: View {
    let transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "creditcard.fill",
                        description: Text("Add your first transaction to start tracking your spending.")
                    )
                } else {
                    ForEach(transactions) { transaction in
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                    }
                    .onDelete(perform: deleteTransactions)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func deleteTransactions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(transactions[index])
            }
        }
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

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let email = authService.email {
                        LabeledContent("Email", value: email)
                    }
                    if let name = authService.displayName {
                        LabeledContent("Name", value: name)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        try? authService.signOut()
                    }
                }

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

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AuthenticationService())
        .modelContainer(.preview)
}

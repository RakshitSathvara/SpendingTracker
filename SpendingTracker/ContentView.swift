//
//  ContentView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    var body: some View {
        NavigationSplitView {
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
                ToolbarItem {
                    Button(action: addSampleTransaction) {
                        Label("Add Transaction", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select a transaction")
        }
    }

    private func addSampleTransaction() {
        withAnimation {
            let newTransaction = Transaction(
                amount: Decimal(Double.random(in: 10...500)),
                title: "Sample Transaction",
                date: Date(),
                type: .expense
            )
            modelContext.insert(newTransaction)
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

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
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

struct TransactionDetailView: View {
    let transaction: Transaction

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Title", value: transaction.title)
                LabeledContent("Amount", value: transaction.formattedAmount)
                LabeledContent("Type", value: transaction.type.rawValue)
                LabeledContent("Date") {
                    Text(transaction.date, format: Date.FormatStyle(date: .long, time: .shortened))
                }
            }

            if let category = transaction.category {
                Section("Category") {
                    Label(category.name, systemImage: category.icon)
                }
            }

            if let paymentMethod = transaction.paymentMethod {
                Section("Payment Method") {
                    Label(paymentMethod.name, systemImage: paymentMethod.type.icon)
                }
            }

            if let notes = transaction.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}

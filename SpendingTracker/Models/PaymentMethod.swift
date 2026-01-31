//
//  PaymentMethod.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData

enum PaymentMethodType: String, Codable, CaseIterable {
    case cash = "Cash"
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case bankTransfer = "Bank Transfer"
    case upi = "UPI"
    case wallet = "Digital Wallet"
    case other = "Other"

    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .bankTransfer: return "building.columns.fill"
        case .upi: return "qrcode"
        case .wallet: return "wallet.pass.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

@Model
final class PaymentMethod {
    var name: String
    var typeRawValue: String
    var isDefault: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Transaction.paymentMethod)
    var transactions: [Transaction]?

    var type: PaymentMethodType {
        get { PaymentMethodType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        type: PaymentMethodType,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.typeRawValue = type.rawValue
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    static var defaultPaymentMethods: [PaymentMethod] {
        [
            PaymentMethod(name: "Cash", type: .cash, isDefault: true),
            PaymentMethod(name: "Credit Card", type: .creditCard),
            PaymentMethod(name: "Debit Card", type: .debitCard),
            PaymentMethod(name: "UPI", type: .upi)
        ]
    }
}

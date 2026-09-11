//
//  Wallet.swift
//  ChargePath
//
//  In-app charging balance + payment history (Settings › Wallet).
//  All amounts are CAD, stored as a plain Double of dollars — fine for a
//  Test-Mode mock; a real build would use Decimal / minor units.
//

import Foundation

struct Wallet: Equatable, Codable {
    var balance: Double
    var transactions: [WalletTransaction]

    /// Seed used before anything is persisted — matches the mockup.
    static let seed = Wallet(
        balance: 42.50,
        transactions: [
            WalletTransaction(title: "Marché Central · A1",
                              subtitle: "Sep 3 · 32 kWh · 41 min",
                              amount: -12.16, kind: .debit),
            WalletTransaction(title: "Top-up · Sandbox card 4242",
                              subtitle: "Sep 1",
                              amount: 25.00, kind: .credit),
            WalletTransaction(title: "Rosemont Co-op · D1",
                              subtitle: "Aug 28 · 18 kWh · 24 min",
                              amount: -5.22, kind: .debit),
            WalletTransaction(title: "Plateau Garage · B2",
                              subtitle: "Aug 22 · 9 kWh · 1 h 20",
                              amount: -3.06, kind: .debit)
        ]
    )
}

struct WalletTransaction: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    /// Signed dollars: negative = spent, positive = added.
    let amount: Double
    let kind: Kind

    enum Kind: String, Equatable, Codable { case credit, debit }

    init(id: UUID = UUID(), title: String, subtitle: String, amount: Double, kind: Kind) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.kind = kind
    }

    /// "+$25.00" / "-$12.16".
    var amountText: String {
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", abs(amount)))"
    }
}

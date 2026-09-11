//
//  WalletRepository.swift
//  ChargePath
//
//  In-app charging balance + history for Settings › Wallet. Persisted locally;
//  seeded from `Wallet.seed` (the mockup's numbers) on first run.
//

import Foundation
import RxSwift
import RxRelay

protocol WalletRepository: AnyObject {
    var wallet: Observable<Wallet> { get }
    var currentWallet: Wallet { get }
    /// Add funds via the (mock) sandbox card and record a credit transaction.
    func addFunds(_ amount: Double)
    /// Debit the balance and record a spend (e.g. a finished charging session).
    func charge(_ amount: Double, title: String, subtitle: String)
}

final class DefaultWalletRepository: WalletRepository {

    private enum Key { static let wallet = "wallet.state" }

    private let store: KeyValueStore
    private let relay: BehaviorRelay<Wallet>

    var wallet: Observable<Wallet> { relay.asObservable() }
    var currentWallet: Wallet { relay.value }

    init(store: KeyValueStore) {
        self.store = store
        let saved = store.codable(Wallet.self, forKey: Key.wallet) ?? .seed
        self.relay = BehaviorRelay(value: saved)
    }

    func addFunds(_ amount: Double) {
        guard amount > 0 else { return }
        var wallet = relay.value
        wallet.balance += amount
        wallet.transactions.insert(
            WalletTransaction(
                title: "Top-up · Sandbox card 4242",
                subtitle: "Just now",
                amount: amount,
                kind: .credit
            ),
            at: 0
        )
        relay.accept(wallet)
        store.setCodable(wallet, forKey: Key.wallet)
    }

    func charge(_ amount: Double, title: String, subtitle: String) {
        guard amount > 0 else { return }
        var wallet = relay.value
        wallet.balance -= amount
        wallet.transactions.insert(
            WalletTransaction(title: title, subtitle: subtitle,
                              amount: -amount, kind: .debit),
            at: 0
        )
        relay.accept(wallet)
        store.setCodable(wallet, forKey: Key.wallet)
    }
}

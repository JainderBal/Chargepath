//
//  WalletViewModel.swift
//  ChargePath
//
//  Backs Settings › Wallet: balance card, top-up amount chips, "add funds"
//  (mock sandbox card), and payment history.
//

import Foundation
import RxSwift
import RxRelay

final class WalletViewModel {

    // MARK: Injected dependencies
    private let walletRepository: WalletRepository
    private let localizationRepository: LocalizationRepository

    // MARK: Outputs
    let balanceText = BehaviorRelay<String>(value: "")
    let transactions = BehaviorRelay<[WalletTransaction]>(value: [])
    let selectedTopUp = BehaviorRelay<Double>(value: 25)
    let addFundsLabel = BehaviorRelay<String>(value: "")
    let strings: BehaviorRelay<Strings>

    /// Fixed top-up options from the mockup.
    let topUpAmounts: [Double] = [10, 25, 50]

    private let disposeBag = DisposeBag()

    init(walletRepository: WalletRepository,
         localizationRepository: LocalizationRepository) {
        self.walletRepository = walletRepository
        self.localizationRepository = localizationRepository
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)

        localizationRepository.strings.bind(to: strings).disposed(by: disposeBag)

        walletRepository.wallet
            .map { "$\(String(format: "%.2f", $0.balance))" }
            .bind(to: balanceText)
            .disposed(by: disposeBag)

        walletRepository.wallet
            .map(\.transactions)
            .bind(to: transactions)
            .disposed(by: disposeBag)

        // "Add $25 · Test Mode" — recomputed when the amount or language changes.
        Observable.combineLatest(selectedTopUp, strings)
            .map { amount, strings in
                strings.walletAddFundsPrefix + "$\(Int(amount))"
                    + (strings.testModeBadge == "MODE TEST" ? " (test)" : " · Test Mode")
            }
            .bind(to: addFundsLabel)
            .disposed(by: disposeBag)
    }

    // MARK: Inputs

    func selectTopUp(_ amount: Double) {
        selectedTopUp.accept(amount)
    }

    func addFunds() {
        walletRepository.addFunds(selectedTopUp.value)
    }
}

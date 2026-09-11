//
//  ChargingSessionTests.swift
//  ChargePathTests
//

import XCTest
import RxSwift
@testable import ChargePath

final class WalletChargeTests: XCTestCase {

    func test_charge_debits_balance_and_records_a_spend() {
        let repo = DefaultWalletRepository(store: InMemoryKeyValueStore())
        let before = repo.currentWallet.balance

        repo.charge(5.32, title: "Marché Central · A1", subtitle: "Just now · 14 kWh · 22 min")

        XCTAssertEqual(repo.currentWallet.balance, before - 5.32, accuracy: 0.001)
        let tx = repo.currentWallet.transactions.first
        XCTAssertEqual(tx?.kind, .debit)
        XCTAssertEqual(tx?.amount, -5.32)
        XCTAssertEqual(tx?.amountText, "-$5.32")
    }

    func test_charge_ignores_non_positive() {
        let repo = DefaultWalletRepository(store: InMemoryKeyValueStore())
        let before = repo.currentWallet
        repo.charge(0, title: "x", subtitle: "x")
        repo.charge(-3, title: "x", subtitle: "x")
        XCTAssertEqual(repo.currentWallet, before)
    }
}

@MainActor
final class ChargingSessionRepositoryTests: XCTestCase {

    private func makeSUT(balance: Double) -> (DefaultChargingSessionRepository, WalletRepositoryDouble) {
        let wallet = WalletRepositoryDouble(balance: balance)
        let repo = DefaultChargingSessionRepository(
            payment: MockPaymentAuthService(simulatedLatency: .milliseconds(1)),
            walletRepository: wallet)
        return (repo, wallet)
    }

    private func station() -> Station {
        Fixture.station(id: "s1", connectors: [.ccs], ports: [
            ChargingPort(id: "p1", label: "A1", connector: .ccs, powerKW: 150, status: .available, note: nil)
        ])
    }

    func test_start_fails_when_balance_below_hold() throws {
        let (repo, _) = makeSUT(balance: 10)   // hold is $25
        let error = try awaitError(repo.startSession(station: station(), port: station().ports[0]))
        guard case ChargingSessionError.insufficientFunds(let needed, let available) = error else {
            return XCTFail("expected insufficientFunds, got \(error)")
        }
        XCTAssertEqual(needed, 25)
        XCTAssertEqual(available, 10)
        XCTAssertNil(repo.currentSession)
    }

    func test_start_publishes_an_active_session() throws {
        let (repo, _) = makeSUT(balance: 100)
        let session = try awaitValue(repo.startSession(station: station(), port: station().ports[0]))
        XCTAssertEqual(session.stationName, "Test Station")
        XCTAssertEqual(session.portLabel, "A1")
        XCTAssertEqual(session.powerKW, 150)
        XCTAssertNotNil(repo.currentSession)
        _ = try awaitValue(repo.stopSession())   // clean up the timer
    }

    func test_stop_settles_the_wallet_and_clears_the_session() throws {
        let (repo, wallet) = makeSUT(balance: 100)
        _ = try awaitValue(repo.startSession(station: station(), port: station().ports[0]))
        let receipt = try awaitValue(repo.stopSession())

        XCTAssertNil(repo.currentSession)
        XCTAssertGreaterThan(receipt.totalCharged, 0)
        XCTAssertEqual(wallet.charges.count, 1)
        XCTAssertEqual(wallet.charges.first?.amount ?? 0, receipt.totalCharged, accuracy: 0.001)
        XCTAssertEqual(wallet.currentWallet.balance, 100 - receipt.totalCharged, accuracy: 0.001)
    }

    func test_stop_without_a_session_errors() throws {
        let (repo, _) = makeSUT(balance: 100)
        let error = try awaitError(repo.stopSession())
        XCTAssertEqual(error as? ChargingSessionError, .noActiveSession)
    }

    func test_stop_broadcasts_the_receipt_on_finishedReceipt() throws {
        let (repo, _) = makeSUT(balance: 100)
        _ = try awaitValue(repo.startSession(station: station(), port: station().ports[0]))

        let exp = expectation(description: "finishedReceipt")
        var broadcast: ChargingSessionReceipt?
        let d = repo.finishedReceipt.subscribe(onNext: { broadcast = $0; exp.fulfill() })
        defer { d.dispose() }

        let returned = try awaitValue(repo.stopSession())
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(broadcast, returned)          // same receipt both ways
        XCTAssertNil(repo.currentSession)
    }

    func test_rate_parsing() {
        XCTAssertEqual(DefaultChargingSessionRepository.parseRate(from: "$0.38 / kWh"), 0.38, accuracy: 0.0001)
        XCTAssertEqual(DefaultChargingSessionRepository.parseRate(from: nil), 0.35, accuracy: 0.0001)
        XCTAssertEqual(DefaultChargingSessionRepository.parseRate(from: "free"), 0.35, accuracy: 0.0001)
    }
}

// Block on a Single that is expected to fail.
func awaitError<T>(_ single: Single<T>, timeout: TimeInterval = 5) throws -> Error {
    let exp = XCTestExpectation(description: "Single error")
    var captured: Error?
    let d = single.subscribe(onSuccess: { _ in exp.fulfill() },
                             onFailure: { captured = $0; exp.fulfill() })
    defer { d.dispose() }
    _ = XCTWaiter().wait(for: [exp], timeout: timeout)
    return try XCTUnwrap(captured, "Single succeeded but an error was expected")
}

//
//  ChargingSessionRepository.swift
//  ChargePath
//
//  Owns the charging-session lifecycle:
//    start  → check the wallet covers the pre-auth hold, authorise it (mock),
//             begin a timer-driven *simulated* session (energy accrues from
//             the port's kW, time-compressed for the demo)
//    stop   → settle the real energy cost against the wallet, emit a receipt
//
//  There is at most ONE active session app-wide, exposed as an Observable so
//  the Map / Station Detail can lock out other activations while it runs.
//

import Foundation
import RxSwift
import RxRelay

enum ChargingSessionError: Error, Equatable {
    case insufficientFunds(needed: Double, available: Double)
    case noActiveSession
    case sessionAlreadyActive
}

protocol ChargingSessionRepository: AnyObject {
    var activeSession: Observable<ActiveChargingSession?> { get }
    var currentSession: ActiveChargingSession? { get }

    /// Emits whenever a session settles — whether the user tapped Stop or it
    /// auto-stopped at its target. The live screen listens so it can show the
    /// receipt in both cases instead of only when the user drove the stop.
    var finishedReceipt: Observable<ChargingSessionReceipt> { get }

    /// Places the hold and starts the simulated session.
    func startSession(station: Station, port: ChargingPort) -> Single<ActiveChargingSession>

    /// Stops the session, charges the wallet for the energy used, returns a receipt.
    func stopSession() -> Single<ChargingSessionReceipt>
}

final class DefaultChargingSessionRepository: ChargingSessionRepository {

    /// Pre-auth hold amount (a real processor releases the unused part on stop).
    static let holdAmount: Double = 25
    /// Flat connection fee added to every session.
    static let sessionFee: Double = 1.00
    /// Demo time compression — 1 real second ≈ this many charging seconds, so
    /// a session runs its course in a few seconds.
    static let timeCompression: Double = 120

    private let payment: PaymentAuthService
    private let walletRepository: WalletRepository
    private let relay = BehaviorRelay<ActiveChargingSession?>(value: nil)
    private let receiptRelay = PublishRelay<ChargingSessionReceipt>()
    private var timer: Timer?

    var activeSession: Observable<ActiveChargingSession?> { relay.asObservable() }
    var currentSession: ActiveChargingSession? { relay.value }
    var finishedReceipt: Observable<ChargingSessionReceipt> { receiptRelay.asObservable() }

    init(payment: PaymentAuthService, walletRepository: WalletRepository) {
        self.payment = payment
        self.walletRepository = walletRepository
    }

    // MARK: Start

    func startSession(station: Station, port: ChargingPort) -> Single<ActiveChargingSession> {
        if relay.value != nil { return .error(ChargingSessionError.sessionAlreadyActive) }

        let available = walletRepository.currentWallet.balance
        guard available >= Self.holdAmount else {
            return .error(ChargingSessionError.insufficientFunds(
                needed: Self.holdAmount, available: available))
        }

        let rate = Self.parseRate(from: station.priceText)
        return payment.authorizeHold(amount: Self.holdAmount)
            .map { [weak self] _ -> ActiveChargingSession in
                let session = ActiveChargingSession(
                    id: UUID(),
                    stationID: station.id,
                    stationName: station.name,
                    portID: port.id,
                    portLabel: port.label,
                    powerKW: max(port.powerKW, 3),
                    ratePerKWh: rate,
                    sessionFee: Self.sessionFee,
                    holdAmount: Self.holdAmount,
                    startedAt: Date()
                )
                self?.relay.accept(session)
                self?.startTimer()
                return session
            }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard var session = relay.value else { return }
        let kWhPerSecond = Double(session.powerKW) / 3600
        session.energyKWh += kWhPerSecond * Self.timeCompression
        session.elapsedSeconds += Self.timeCompression

        if session.energyKWh >= session.targetEnergyKWh {
            session.energyKWh = session.targetEnergyKWh
            relay.accept(session)
            _ = stopSession().subscribe()          // auto-stop at the target
        } else {
            relay.accept(session)
        }
    }

    // MARK: Stop

    func stopSession() -> Single<ChargingSessionReceipt> {
        guard let session = relay.value else { return .error(ChargingSessionError.noActiveSession) }
        timer?.invalidate()
        timer = nil

        let total = (session.runningCost * 100).rounded() / 100
        let minutes = Int((session.elapsedSeconds / 60).rounded())
        walletRepository.charge(
            total,
            title: "\(session.stationName) · \(session.portLabel)",
            subtitle: "Just now · \(Int(session.energyKWh.rounded())) kWh · \(minutes) min"
        )

        let receipt = ChargingSessionReceipt(
            stationName: session.stationName,
            portLabel: session.portLabel,
            energyKWh: session.energyKWh,
            durationMinutes: minutes,
            ratePerKWh: session.ratePerKWh,
            sessionFee: session.sessionFee,
            totalCharged: total,
            isTestMode: true
        )
        // Broadcast the receipt *before* clearing the session, so a live screen
        // observing both sees the receipt first and shows it (rather than
        // treating the nil as "session ended elsewhere, just close").
        receiptRelay.accept(receipt)
        relay.accept(nil)
        return .just(receipt)
    }

    // MARK: Helpers

    /// "$0.38 / kWh" → 0.38 (defaults to 0.35 when unparseable).
    static func parseRate(from priceText: String?) -> Double {
        guard let priceText else { return 0.35 }
        let scanner = Scanner(string: priceText)
        _ = scanner.scanUpToCharacters(from: .decimalDigits)
        return scanner.scanDouble() ?? 0.35
    }
}

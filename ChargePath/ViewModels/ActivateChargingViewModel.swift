//
//  ActivateChargingViewModel.swift
//  ChargePath
//
//  Two steps: pick a port → confirm (places the pre-auth hold and starts a
//  live session). "Success" is leaving this flow for the Active Session
//  screen, so there is no third step here.
//

import Foundation
import RxSwift
import RxRelay

final class ActivateChargingViewModel {

    // MARK: Injected dependencies
    private let station: Station
    private let chargingSessionRepository: ChargingSessionRepository
    private let localizationRepository: LocalizationRepository

    // MARK: Navigation hooks
    var onSessionStarted: ((ActiveChargingSession) -> Void)?
    var onNeedsFunds: (() -> Void)?
    var onCancel: (() -> Void)?

    // MARK: Outputs
    let step = BehaviorRelay<ActivateChargingStep>(value: .selectPort)
    let selectedPort = BehaviorRelay<ChargingPort?>(value: nil)
    let isProcessing = BehaviorRelay<Bool>(value: false)
    /// Non-nil when the wallet can't cover the hold — the VC shows it + an
    /// "Add funds" affordance.
    let insufficientFunds = BehaviorRelay<String?>(value: nil)
    let strings: BehaviorRelay<Strings>

    /// Ports the user may pick — offline ports excluded.
    let selectablePorts: [ChargingPort]
    let stationName: String
    var rateText: String { station.priceText ?? "—" }
    var holdText: String { "$\(String(format: "%.0f", DefaultChargingSessionRepository.holdAmount))" }

    private let disposeBag = DisposeBag()

    init(station: Station,
         chargingSessionRepository: ChargingSessionRepository,
         localizationRepository: LocalizationRepository) {
        self.station = station
        self.chargingSessionRepository = chargingSessionRepository
        self.localizationRepository = localizationRepository
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)
        self.selectablePorts = station.ports.filter { $0.status != .offline }
        self.stationName = station.name

        localizationRepository.strings.bind(to: strings).disposed(by: disposeBag)
    }

    // MARK: Inputs

    func selectPort(_ port: ChargingPort) { selectedPort.accept(port) }

    func continueToPayment() {
        guard selectedPort.value != nil else { return }
        step.accept(.confirmPayment)
    }

    func confirmPayment() {
        guard let port = selectedPort.value, !isProcessing.value else { return }
        isProcessing.accept(true)
        insufficientFunds.accept(nil)

        chargingSessionRepository.startSession(station: station, port: port)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onSuccess: { [weak self] session in
                    self?.isProcessing.accept(false)
                    self?.onSessionStarted?(session)
                },
                onFailure: { [weak self] error in
                    self?.isProcessing.accept(false)
                    if case ChargingSessionError.insufficientFunds(let needed, let available) = error {
                        self?.insufficientFunds.accept(
                            "Your balance is $\(String(format: "%.2f", available)) — a "
                            + "$\(String(format: "%.0f", needed)) hold is needed to start.")
                    }
                }
            )
            .disposed(by: disposeBag)
    }

    func addFunds() { onNeedsFunds?() }
    func cancel() { onCancel?() }
}

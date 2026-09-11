//
//  ActiveSessionViewModel.swift
//  ChargePath
//
//  Backs the live charging screen: elapsed time, simulated energy, running
//  cost, and a Stop button that settles the wallet and shows a receipt.
//

import Foundation
import RxSwift
import RxRelay

final class ActiveSessionViewModel {

    // MARK: Injected
    private let chargingSessionRepository: ChargingSessionRepository
    private let localizationRepository: LocalizationRepository

    // MARK: Navigation
    var onFinished: (() -> Void)?

    // MARK: Outputs
    let strings: BehaviorRelay<Strings>
    let stationLine = BehaviorRelay<String>(value: "")
    let elapsedText = BehaviorRelay<String>(value: "0 min")
    let energyText = BehaviorRelay<String>(value: "0.0 kWh")
    let costText = BehaviorRelay<String>(value: "$0.00")
    let powerText = BehaviorRelay<String>(value: "")
    let progress = BehaviorRelay<Float>(value: 0)
    let isStopping = BehaviorRelay<Bool>(value: false)
    /// Set once the session has stopped — the VC swaps to the receipt view.
    let receipt = BehaviorRelay<ChargingSessionReceipt?>(value: nil)

    private let disposeBag = DisposeBag()

    init(chargingSessionRepository: ChargingSessionRepository,
         localizationRepository: LocalizationRepository) {
        self.chargingSessionRepository = chargingSessionRepository
        self.localizationRepository = localizationRepository
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)
        localizationRepository.strings.bind(to: strings).disposed(by: disposeBag)

        chargingSessionRepository.activeSession
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] session in
                guard let self else { return }
                if let session {
                    self.render(session)
                } else if self.receipt.value == nil, !self.isStopping.value {
                    // Session cleared with no receipt in hand. A finishedReceipt
                    // emission normally lands first; give it one run-loop hop to
                    // arrive before treating this as a bare "ended elsewhere".
                    DispatchQueue.main.async {
                        if self.receipt.value == nil { self.onFinished?() }
                    }
                }
            })
            .disposed(by: disposeBag)

        // Auto-stop (session reaches its target) settles the wallet in the
        // repository and emits here — show the receipt just like a manual stop.
        chargingSessionRepository.finishedReceipt
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] receipt in
                guard let self else { return }
                self.isStopping.accept(false)
                if self.receipt.value == nil { self.receipt.accept(receipt) }
            })
            .disposed(by: disposeBag)
    }

    // MARK: Inputs

    func stopTapped() {
        guard !isStopping.value, receipt.value == nil else { return }
        isStopping.accept(true)
        chargingSessionRepository.stopSession()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] receipt in
                self?.isStopping.accept(false)
                self?.receipt.accept(receipt)
            }, onFailure: { [weak self] _ in
                self?.isStopping.accept(false)
                self?.onFinished?()
            })
            .disposed(by: disposeBag)
    }

    func done() { onFinished?() }

    // MARK: Render

    private func render(_ s: ActiveChargingSession) {
        stationLine.accept("\(s.stationName) · \(s.portLabel)")
        powerText.accept("\(s.powerKW) kW")
        elapsedText.accept("\(Int((s.elapsedSeconds / 60).rounded())) min")
        energyText.accept(String(format: "%.1f kWh", s.energyKWh))
        costText.accept(String(format: "$%.2f", s.runningCost))
        progress.accept(Float(min(1, s.energyKWh / max(s.targetEnergyKWh, 0.001))))
    }
}

//
//  StationDetailViewModel.swift
//  ChargePath
//
//  Backs the Station Detail bottom sheet. On appear it flips to a "checking
//  live status" state, refreshes per-port status through the repository, then
//  settles on "Live" — mirroring the mockup's `openStation` timing.
//

import Foundation
import RxSwift
import RxRelay

final class StationDetailViewModel {

    enum LiveState: Equatable { case checking, live }

    // MARK: Injected dependencies
    private let stationRepository: StationRepository
    private let bookmarkRepository: BookmarkRepository
    private let vehicleRepository: VehicleRepository
    private let localizationRepository: LocalizationRepository
    private let chargingSessionRepository: ChargingSessionRepository

    // MARK: Navigation hooks
    var onStartCharging: ((Station) -> Void)?

    // MARK: Outputs
    let station: BehaviorRelay<Station>
    let isBookmarked = BehaviorRelay<Bool>(value: false)
    let liveState = BehaviorRelay<LiveState>(value: .checking)
    let vehicleConnector = BehaviorRelay<Connector>(value: .unknown)
    /// "Start charging" button state — disabled while another session runs.
    let startEnabled = BehaviorRelay<Bool>(value: true)
    let startTitle = BehaviorRelay<String>(value: "")
    let strings: BehaviorRelay<Strings>

    private let disposeBag = DisposeBag()

    init(station: Station,
         stationRepository: StationRepository,
         bookmarkRepository: BookmarkRepository,
         vehicleRepository: VehicleRepository,
         localizationRepository: LocalizationRepository,
         chargingSessionRepository: ChargingSessionRepository) {
        self.station = BehaviorRelay(value: station)
        self.stationRepository = stationRepository
        self.bookmarkRepository = bookmarkRepository
        self.vehicleRepository = vehicleRepository
        self.localizationRepository = localizationRepository
        self.chargingSessionRepository = chargingSessionRepository
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)

        bind()
    }

    // MARK: Inputs

    /// Re-point the (already visible) sheet at a different station — e.g. the
    /// user tapped another pin while this sheet was open.
    func present(_ newStation: Station) {
        guard newStation.id != station.value.id else { return }
        station.accept(newStation)
        onAppear()
    }

    func onAppear() {
        liveState.accept(.checking)
        stationRepository.refreshLiveStatus(for: station.value)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] updated in
                // .live first: the VC re-renders port rows off `station`, and
                // that render reads `liveState` to decide "···" vs real status.
                self?.liveState.accept(.live)
                self?.station.accept(updated)
            })
            .disposed(by: disposeBag)
    }

    func toggleBookmark() {
        bookmarkRepository.toggle(station.value.id)
    }

    func startCharging() {
        guard startEnabled.value else { return }
        onStartCharging?(station.value)
    }

    // MARK: Binding

    private func bind() {
        localizationRepository.strings
            .bind(to: strings)
            .disposed(by: disposeBag)

        vehicleRepository.selectedVehicle
            .map(\.connector)
            .bind(to: vehicleConnector)
            .disposed(by: disposeBag)

        // Reactive to the *current* station id so it stays correct after
        // present(_:) swaps the station.
        Observable.combineLatest(station, bookmarkRepository.bookmarkedStationIDs)
            .map { station, ids in ids.contains(station.id) }
            .bind(to: isBookmarked)
            .disposed(by: disposeBag)

        // "Start charging" locks out while any session is running.
        Observable.combineLatest(chargingSessionRepository.activeSession, strings)
            .subscribe(onNext: { [weak self] session, strings in
                self?.startEnabled.accept(session == nil)
                self?.startTitle.accept(
                    session == nil ? strings.stationStartCharging : strings.startChargingBusy)
            })
            .disposed(by: disposeBag)
    }
}

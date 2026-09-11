//
//  NavigationViewModel.swift
//  ChargePath
//
//  Backs the in-app turn-by-turn Navigation screen. It owns the route's
//  waypoint list and drives a `TurnByTurnNavigator` (Google Navigation SDK
//  behind the protocol seam); the ViewController supplies the concrete
//  navigator once its map view exists, via `bind(navigator:)`.
//

import Foundation
import CoreLocation
import RxSwift
import RxRelay

final class NavigationViewModel {

    // MARK: Injected
    private let waypoints: [NavWaypoint]
    private let localizationRepository: LocalizationRepository
    private var navigator: TurnByTurnNavigator?

    // MARK: Navigation hooks
    var onExit: (() -> Void)?

    // MARK: Outputs
    let strings: BehaviorRelay<Strings>
    let destinationName: BehaviorRelay<String>
    let etaText = BehaviorRelay<String>(value: "—")
    let distanceText = BehaviorRelay<String>(value: "")
    let maneuverText = BehaviorRelay<String>(value: "")
    let isNavigating = BehaviorRelay<Bool>(value: false)
    /// Non-nil → the VC shows a placeholder instead of a live map (no SDK / no
    /// API key / route failed).
    let unavailableText = BehaviorRelay<String?>(value: nil)
    let arrived = PublishRelay<Void>()

    private let disposeBag = DisposeBag()

    init(waypoints: [NavWaypoint], localizationRepository: LocalizationRepository) {
        self.waypoints = waypoints
        self.localizationRepository = localizationRepository
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)
        self.destinationName = BehaviorRelay(value: waypoints.last?.title ?? "")

        localizationRepository.strings.bind(to: strings).disposed(by: disposeBag)
    }

    // MARK: Inputs

    /// Called by the VC once its navigation map view — and therefore the
    /// concrete navigator — exists.
    func bind(navigator: TurnByTurnNavigator) {
        self.navigator = navigator

        guard navigator.isAvailable else {
            unavailableText.accept(strings.value.navUnavailable)
            return
        }

        navigator.updates
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.apply($0) })
            .disposed(by: disposeBag)

        navigator.didArrive
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                self.isNavigating.accept(false)
                self.maneuverText.accept(self.strings.value.navArrived)
                self.arrived.accept(())
            })
            .disposed(by: disposeBag)

        startGuidance()
    }

    /// "End" button.
    func stop() {
        navigator?.stopGuidance()
        isNavigating.accept(false)
        onExit?()
    }

    // MARK: Internals

    private func startGuidance() {
        guard let navigator, !waypoints.isEmpty else { return }
        navigator.setDestinations(waypoints)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                navigator.startGuidance()
                self?.isNavigating.accept(true)
            }, onFailure: { [weak self] error in
                self?.unavailableText.accept(Self.message(for: error, strings: self?.strings.value))
            })
            .disposed(by: disposeBag)
    }

    /// `.unavailable` (no key / SDK not linked) reuses the "set your key"
    /// copy; anything else (route/location failure) surfaces the vendor's
    /// reason so "I added the key and it still says that" is diagnosable
    /// instead of reading identically to a missing key.
    private static func message(for error: Error, strings: Strings?) -> String {
        if case TurnByTurnError.routeFailed(let reason) = error {
            return "Couldn't start navigation (\(reason)). Check location permission is granted and, on the simulator, that a location is set (Features ▸ Location)."
        }
        return strings?.navUnavailable ?? ""
    }

    private func apply(_ update: NavUpdate) {
        etaText.accept(RoutePlan.durationText(update.etaSeconds))
        distanceText.accept(Self.distanceText(update.distanceMeters))
        if !update.maneuverText.isEmpty { maneuverText.accept(update.maneuverText) }
    }

    static func distanceText(_ meters: CLLocationDistance) -> String {
        meters < 1000
            ? "\(Int(meters)) m"
            : String(format: "%.1f km", meters / 1000)
    }

    // MARK: Waypoint builders

    /// Charging stops in order, then the final destination. The typed origin is
    /// omitted — the engine starts from the live GPS fix.
    static func waypoints(for plan: RoutePlan, destinationTitle: String) -> [NavWaypoint] {
        var out = plan.stops.map {
            NavWaypoint(coordinate: $0.station.coordinate, title: $0.station.name)
        }
        out.append(NavWaypoint(coordinate: plan.destination, title: destinationTitle))
        return out
    }

    /// A single-destination drive straight to one station.
    static func waypoints(for station: Station) -> [NavWaypoint] {
        [NavWaypoint(coordinate: station.coordinate, title: station.name)]
    }
}

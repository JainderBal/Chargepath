//
//  MapViewModel.swift
//  ChargePath
//
//  Backs the Map tab. Combines the station cache, the active filter, the
//  bookmark set and the selected vehicle into one `visibleStations` stream —
//  a direct port of the mockup's `visible()` predicate.
//
//  All dependencies are injected; the ViewModel creates none of them.
//

import Foundation
import MapKit
import RxSwift
import RxRelay

final class MapViewModel {

    // MARK: Injected dependencies
    private let stationRepository: StationRepository
    private let bookmarkRepository: BookmarkRepository
    private let vehicleRepository: VehicleRepository
    private let localizationRepository: LocalizationRepository
    private let locationService: LocationService
    private let chargingSessionRepository: ChargingSessionRepository

    // MARK: Navigation hooks (set by the coordinator)
    var onSelectStation: ((Station) -> Void)?
    var onOpenFilters: ((StationFilter) -> Void)?
    var onOpenActiveSession: (() -> Void)?

    // MARK: Outputs
    let filter: BehaviorRelay<StationFilter>
    let visibleStations = BehaviorRelay<[Station]>(value: [])
    let resultLine = BehaviorRelay<String>(value: "")
    let strings: BehaviorRelay<Strings>

    /// Connector the current vehicle uses — drives the "fits your car"
    /// highlight on badges.
    let vehicleConnector = BehaviorRelay<Connector>(value: .unknown)

    /// Non-nil when the map is showing seed data instead of live — the VC
    /// shows a slim banner with this text.
    let statusBanner = BehaviorRelay<String?>(value: nil)

    /// Fires a coordinate when the user taps "locate me" and a fix is available.
    let recenterOnUser = PublishRelay<CLLocationCoordinate2D>()

    /// Non-nil while a charging session is running — the VC shows a tappable
    /// "charging now" banner that opens the live session screen.
    let activeSessionBanner = BehaviorRelay<String?>(value: nil)

    private let userLocation = BehaviorRelay<CLLocation?>(value: nil)
    private let regionRelay = PublishRelay<MKCoordinateRegion>()
    private let recenterRequested = PublishRelay<Void>()
    private let disposeBag = DisposeBag()

    init(stationRepository: StationRepository,
         bookmarkRepository: BookmarkRepository,
         vehicleRepository: VehicleRepository,
         localizationRepository: LocalizationRepository,
         locationService: LocationService,
         chargingSessionRepository: ChargingSessionRepository) {
        self.stationRepository = stationRepository
        self.bookmarkRepository = bookmarkRepository
        self.vehicleRepository = vehicleRepository
        self.localizationRepository = localizationRepository
        self.locationService = locationService
        self.chargingSessionRepository = chargingSessionRepository

        self.filter = BehaviorRelay(value: .default)
        self.strings = BehaviorRelay(value: localizationRepository.currentStrings)

        bind()
    }

    // MARK: Inputs

    /// Called from the VC's `viewDidAppear` — ask for location permission once.
    func onAppear() {
        locationService.requestWhenInUseAuthorization()
    }

    /// "Locate me" button.
    func locateTapped() {
        recenterRequested.accept(())
        locationService.requestLocation()
    }

    func openActiveSession() { onOpenActiveSession?() }

    func updateQuery(_ text: String) {
        var f = filter.value
        f.query = text
        filter.accept(f)
    }

    func setSegment(_ segment: StationFilter.Segment) {
        var f = filter.value
        f.segment = segment
        filter.accept(f)
    }

    func applyFilter(_ updated: StationFilter) {
        filter.accept(updated)
    }

    func openFilters() {
        onOpenFilters?(filter.value)
    }

    /// Called by the VC on every pan/zoom — funnelled through a relay so the
    /// binding can debounce before hitting the repository / network.
    func regionChanged(_ region: MKCoordinateRegion) {
        regionRelay.accept(region)
    }

    func updateUserLocation(_ location: CLLocation) {
        userLocation.accept(location)
    }

    func selectStation(id: String) {
        guard let station = stationRepository.station(withID: id) else { return }
        onSelectStation?(station)
    }

    // MARK: Binding

    private func bind() {
        // Debounced region → repository fetch (seed fallback on failure).
        regionRelay
            .debounce(.milliseconds(400), scheduler: MainScheduler.instance)
            .flatMapLatest { [stationRepository] region in
                stationRepository.loadStations(in: region).catchAndReturn([])
            }
            .subscribe()
            .disposed(by: disposeBag)

        localizationRepository.strings
            .bind(to: strings)
            .disposed(by: disposeBag)

        vehicleRepository.selectedVehicle
            .map(\.connector)
            .bind(to: vehicleConnector)
            .disposed(by: disposeBag)

        // The core pipeline: recompute the visible set whenever any input moves.
        Observable
            .combineLatest(
                stationRepository.stations,
                filter,
                bookmarkRepository.bookmarkedStationIDs,
                vehicleRepository.selectedVehicle,
                userLocation
            )
            .map { [weak self] stations, filter, bookmarks, vehicle, location -> [Station] in
                self?.applyRules(
                    to: stations, filter: filter, bookmarks: bookmarks,
                    vehicle: vehicle, userLocation: location
                ) ?? []
            }
            .bind(to: visibleStations)
            .disposed(by: disposeBag)

        Observable
            .combineLatest(visibleStations, strings)
            .map { stations, strings in strings.resultsCount(stations.count) }
            .bind(to: resultLine)
            .disposed(by: disposeBag)

        // Location fixes feed the distance/sort pipeline …
        locationService.location
            .bind(to: userLocation)
            .disposed(by: disposeBag)

        // … and, only when the user asked, recentre the map.
        recenterRequested
            .withLatestFrom(locationService.location) { _, location in location.coordinate }
            .bind(to: recenterOnUser)
            .disposed(by: disposeBag)

        // "Charging now" banner.
        Observable.combineLatest(chargingSessionRepository.activeSession, strings)
            .map { session, strings -> String? in
                session.map { strings.sessionMapBanner("\($0.stationName) · \($0.portLabel)") }
            }
            .distinctUntilChanged()
            .bind(to: activeSessionBanner)
            .disposed(by: disposeBag)

        // Banner only for genuine problems — `.seedSparse` is the expected
        // free-tier behaviour and is documented, not surfaced as an error.
        stationRepository.dataSource
            .map { source -> String? in
                switch source {
                case .seedNoKey:        return "No API key — showing sample data"
                case .seedNetworkError: return "Can't reach Open Charge Map — showing sample data"
                case .live, .loading, .seedInitial, .seedSparse: return nil
                }
            }
            .distinctUntilChanged()
            .bind(to: statusBanner)
            .disposed(by: disposeBag)
    }

    private func applyRules(to stations: [Station],
                            filter: StationFilter,
                            bookmarks: Set<String>,
                            vehicle: Vehicle,
                            userLocation: CLLocation?) -> [Station] {
        stations
            .map { station -> Station in
                // Attach straight-line distance if we know where the user is.
                guard let userLocation else { return station }
                var s = station
                let stationLocation = CLLocation(
                    latitude: station.coordinate.latitude,
                    longitude: station.coordinate.longitude
                )
                s.distanceFromUser = userLocation.distance(from: stationLocation)
                return s
            }
            .filter { station in
                filter.matches(
                    station,
                    vehicleConnector: vehicle.connector,
                    isBookmarked: bookmarks.contains(station.id),
                    distanceKm: station.distanceFromUser.map { $0 / 1000 }
                )
            }
            .sorted { ($0.distanceFromUser ?? .greatestFiniteMagnitude)
                        < ($1.distanceFromUser ?? .greatestFiniteMagnitude) }
    }
}

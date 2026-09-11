//
//  Doubles.swift
//  ChargePathTests
//
//  In-memory test doubles for the repository / service protocols. They exist
//  precisely because every dependency in the app is a protocol injected
//  through an initialiser.
//

import Foundation
import MapKit
import RxSwift
import RxRelay
import CoreLocation
@testable import ChargePath

// MARK: Stations

final class StationRepositoryDouble: StationRepository {
    let relay: BehaviorRelay<[Station]>
    let dataSourceRelay = BehaviorRelay<StationDataSource>(value: .seedInitial)
    var loadStationsCallCount = 0
    var liveStatusToMerge: [String: PortStatus] = [:]

    init(_ stations: [Station]) { relay = BehaviorRelay(value: stations) }

    var stations: Observable<[Station]> { relay.asObservable() }
    var dataSource: Observable<StationDataSource> { dataSourceRelay.asObservable() }
    var cachedStations: [Station] { relay.value }

    func loadStations(in region: MKCoordinateRegion) -> Single<[Station]> {
        loadStationsCallCount += 1
        return .just(relay.value)
    }

    func station(withID id: String) -> Station? { relay.value.first { $0.id == id } }

    func refreshLiveStatus(for station: Station) -> Single<Station> {
        guard !liveStatusToMerge.isEmpty else { return .just(station) }
        var updated = station
        updated.ports = station.ports.map { port in
            var port = port
            if let live = liveStatusToMerge[port.id] { port.status = live }
            return port
        }
        return .just(updated)
    }
}

// MARK: Bookmarks

final class BookmarkRepositoryDouble: BookmarkRepository {
    let relay: BehaviorRelay<Set<String>>
    init(_ ids: Set<String> = []) { relay = BehaviorRelay(value: ids) }
    var bookmarkedStationIDs: Observable<Set<String>> { relay.asObservable() }
    func isBookmarked(_ stationID: String) -> Bool { relay.value.contains(stationID) }
    func toggle(_ stationID: String) {
        var s = relay.value
        if s.contains(stationID) { s.remove(stationID) } else { s.insert(stationID) }
        relay.accept(s)
    }
}

// MARK: Vehicle

final class VehicleRepositoryDouble: VehicleRepository {
    let availableVehicles: [Vehicle]
    let relay: BehaviorRelay<Vehicle>
    init(_ vehicles: [Vehicle] = StationSeed.vehicles) {
        availableVehicles = vehicles
        relay = BehaviorRelay(value: vehicles[0])
    }
    var selectedVehicle: Observable<Vehicle> { relay.asObservable() }
    var currentVehicle: Vehicle { relay.value }
    func select(_ vehicle: Vehicle) { relay.accept(vehicle) }
    func selectVehicle(forConnector connector: Connector) {
        if let m = availableVehicles.first(where: { $0.connector == connector }) { relay.accept(m) }
    }
}

// MARK: Localization

final class LocalizationRepositoryDouble: LocalizationRepository {
    let relay = BehaviorRelay<AppLanguage>(value: .en)
    var language: Observable<AppLanguage> { relay.asObservable() }
    var currentLanguage: AppLanguage { relay.value }
    var strings: Observable<Strings> { relay.map(\.strings) }
    var currentStrings: Strings { relay.value.strings }
    func setLanguage(_ language: AppLanguage) { relay.accept(language) }
}

// MARK: Charging session

final class ChargingSessionRepositoryDouble: ChargingSessionRepository {
    let relay = BehaviorRelay<ActiveChargingSession?>(value: nil)
    let receiptRelay = PublishRelay<ChargingSessionReceipt>()
    var startResult: Result<ActiveChargingSession, Error>?
    var stopResult: Result<ChargingSessionReceipt, Error>?
    var startCallCount = 0
    var stopCallCount = 0

    var activeSession: Observable<ActiveChargingSession?> { relay.asObservable() }
    var currentSession: ActiveChargingSession? { relay.value }
    var finishedReceipt: Observable<ChargingSessionReceipt> { receiptRelay.asObservable() }

    func startSession(station: Station, port: ChargingPort) -> Single<ActiveChargingSession> {
        startCallCount += 1
        switch startResult {
        case .success(let s): relay.accept(s); return .just(s)
        case .failure(let e): return .error(e)
        case nil: return .error(ChargingSessionError.noActiveSession)
        }
    }

    func stopSession() -> Single<ChargingSessionReceipt> {
        stopCallCount += 1
        switch stopResult {
        case .success(let r): receiptRelay.accept(r); relay.accept(nil); return .just(r)
        case .failure(let e): relay.accept(nil); return .error(e)
        case nil: relay.accept(nil); return .error(ChargingSessionError.noActiveSession)
        }
    }
}

final class WalletRepositoryDouble: WalletRepository {
    let relay: BehaviorRelay<Wallet>
    private(set) var charges: [(amount: Double, title: String)] = []
    private(set) var credits: [Double] = []

    init(balance: Double = 50) {
        relay = BehaviorRelay(value: Wallet(balance: balance, transactions: []))
    }
    var wallet: Observable<Wallet> { relay.asObservable() }
    var currentWallet: Wallet { relay.value }
    func addFunds(_ amount: Double) {
        credits.append(amount)
        var w = relay.value; w.balance += amount; relay.accept(w)
    }
    func charge(_ amount: Double, title: String, subtitle: String) {
        charges.append((amount, title))
        var w = relay.value; w.balance -= amount; relay.accept(w)
    }
}

// MARK: Location

final class LocationServiceDouble: LocationService {
    let statusRelay = BehaviorRelay<CLAuthorizationStatus>(value: .notDetermined)
    let locationRelay = PublishRelay<CLLocation>()
    var requestWhenInUseCallCount = 0
    var requestLocationCallCount = 0

    var authorizationStatus: Observable<CLAuthorizationStatus> { statusRelay.asObservable() }
    var location: Observable<CLLocation> { locationRelay.asObservable() }
    func requestWhenInUseAuthorization() { requestWhenInUseCallCount += 1 }
    func requestLocation() { requestLocationCallCount += 1 }
}

// MARK: Geocoding / directions

final class GeocodingServiceDouble: GeocodingService {
    var result: Single<CLLocationCoordinate2D> = .error(GeocodingError.notFound)
    func coordinate(for query: String) -> Single<CLLocationCoordinate2D> { result }
}

final class RouteDirectionsServiceDouble: RouteDirectionsService {
    var result: Single<DirectionsResult> = .error(DirectionsError.noRoute)
    func directions(from origin: CLLocationCoordinate2D,
                    to destination: CLLocationCoordinate2D) -> Single<DirectionsResult> { result }
}

// MARK: Fixtures

enum Fixture {
    static func station(id: String,
                        name: String = "Test Station",
                        lat: Double = 45.5,
                        lon: Double = -73.6,
                        connectors: [Connector] = [.ccs],
                        ports: [ChargingPort] = [
                            ChargingPort(id: "p1", label: "P1", connector: .ccs,
                                         powerKW: 150, status: .available, note: nil)
                        ]) -> Station {
        Station(id: id, name: name, address: "1 Test St",
                coordinate: .init(latitude: lat, longitude: lon),
                connectors: connectors, priceText: "$0.30 / kWh",
                ports: ports, distanceFromUser: nil)
    }
}

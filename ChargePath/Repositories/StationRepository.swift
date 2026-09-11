//
//  StationRepository.swift
//  ChargePath
//
//  Domain-facing station data. ViewModels talk to this, never to
//  `StationService` directly. Responsibilities:
//    • call the ChargeHub service for a region
//    • fall back to bundled seed data when the API is unreachable / unkeyed
//    • keep an in-memory cache exposed as an Observable
//    • merge live per-port status onto a cached station on demand
//

import Foundation
import MapKit
import RxSwift
import RxRelay
import OSLog

private let stationLog = Logger(subsystem: "com.chargepath.app", category: "StationRepository")

/// Where the currently-displayed stations came from — surfaced so the Map
/// screen can show a small "showing offline data" banner.
enum StationDataSource: Equatable {
    case loading
    case live(count: Int)
    case seedNoKey          // no ChargeHub key configured
    case seedNetworkError   // the call failed
    case seedSparse         // demo tier returned fewer stations than seed
    case seedInitial        // before the first fetch
}

protocol StationRepository: AnyObject {
    /// Latest known station set (seed data until the first fetch resolves).
    var stations: Observable<[Station]> { get }

    /// What the current `stations` value represents (live / seed + why).
    var dataSource: Observable<StationDataSource> { get }

    /// Synchronous snapshot of the current cache.
    var cachedStations: [Station] { get }

    /// Fetch stations for `region`, update the cache, and return them.
    /// Never errors: on network failure it resolves with seed data.
    func loadStations(in region: MKCoordinateRegion) -> Single<[Station]>

    /// One station from the cache by id.
    func station(withID id: String) -> Station?

    /// Return `station` with fresh live port statuses merged in. On failure the
    /// station is returned unchanged.
    func refreshLiveStatus(for station: Station) -> Single<Station>
}

final class DefaultStationRepository: StationRepository {

    private let service: StationService
    private let seedStations: [Station]
    private let relay: BehaviorRelay<[Station]>
    private let dataSourceRelay = BehaviorRelay<StationDataSource>(value: .seedInitial)

    var stations: Observable<[Station]> { relay.asObservable() }
    var dataSource: Observable<StationDataSource> { dataSourceRelay.asObservable() }
    var cachedStations: [Station] { relay.value }

    init(service: StationService, seedStations: [Station] = StationSeed.stations) {
        self.service = service
        self.seedStations = seedStations
        self.relay = BehaviorRelay(value: seedStations)
    }

    func loadStations(in region: MKCoordinateRegion) -> Single<[Station]> {
        dataSourceRelay.accept(.loading)
        return service.fetchStations(in: region)
            .do(onSuccess: { stationLog.info("Open Charge Map returned \($0.count) stations") })
            // OCM answers real bounding-box queries, so any non-empty result is
            // the live truth for this region and wins over the bundled seed.
            // An empty result (ocean, unmapped area) falls back to the seed so
            // the map never blanks out.
            .map { [seedStations, dataSourceRelay] fetched -> [Station] in
                if fetched.isEmpty {
                    dataSourceRelay.accept(.seedSparse)
                    return seedStations
                }
                dataSourceRelay.accept(.live(count: fetched.count))
                return fetched
            }
            .catch { [seedStations, dataSourceRelay] error in
                stationLog.warning("Open Charge Map fetch failed (\(error)); using seed data")
                let isMissingKey = (error as? APIError) == .missingCredentials
                dataSourceRelay.accept(isMissingKey ? .seedNoKey : .seedNetworkError)
                return .just(seedStations)
            }
            .do(onSuccess: { [relay] in relay.accept($0) })
    }

    func station(withID id: String) -> Station? {
        relay.value.first { $0.id == id } ?? seedStations.first { $0.id == id }
    }

    func refreshLiveStatus(for station: Station) -> Single<Station> {
        service.fetchLiveStatus(locationID: station.id)
            .do(
                onSuccess: { stationLog.info("ChargeHub status: \($0.count) port record(s) for loc \(station.id)") },
                onError: { stationLog.warning("ChargeHub status failed (\($0)); keeping cached status") }
            )
            .map { statusByPortID in
                guard !statusByPortID.isEmpty else { return station }
                var updated = station
                updated.ports = station.ports.map { port in
                    var port = port
                    if let live = statusByPortID[port.id] { port.status = live }
                    return port
                }
                return updated
            }
            .catchAndReturn(station)
            .do(onSuccess: { [relay] merged in
                // Write the merged station back into the cache.
                var all = relay.value
                if let idx = all.firstIndex(where: { $0.id == merged.id }) {
                    all[idx] = merged
                    relay.accept(all)
                }
            })
    }
}

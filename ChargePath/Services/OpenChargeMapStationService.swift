//
//  OpenChargeMapStationService.swift
//  ChargePath
//
//  Live `StationService` backed by Open Charge Map. Same contract as
//  `ChargeHubStationService`; the app wires this one because OCM answers real
//  bounding-box queries. Caching / seed fallback still live in
//  `StationRepository` one layer up.
//

import Foundation
import MapKit
import RxSwift

final class OpenChargeMapStationService: StationService {

    private let apiClient: APIClient
    private let config: APIConfig
    private let maxResults: Int

    init(apiClient: APIClient, config: APIConfig = .default, maxResults: Int = 200) {
        self.apiClient = apiClient
        self.config = config
        self.maxResults = maxResults
    }

    func fetchStations(in region: MKCoordinateRegion) -> Single<[Station]> {
        let route = OpenChargeMapEndpoint.poi(
            region: region,
            apiKey: config.openChargeMapAPIKey,
            maxResults: maxResults
        )
        // The POI endpoint returns a bare JSON array.
        return apiClient.request(route, as: [OCMPoiDTO].self)
            .map { $0.compactMap { $0.toDomain() } }
    }

    /// Open Charge Map publishes no live per-port occupancy feed — operational
    /// state is already folded into the POI response — so there is nothing to
    /// refresh here. Returning empty leaves the cached station untouched.
    func fetchLiveStatus(locationID: String) -> Single<[String: PortStatus]> {
        .just([:])
    }
}

//
//  StationService.swift
//  ChargePath
//
//  Fetches station data from ChargeHub. This is a *Service* — it only knows
//  about the network. Caching, seed-data fallback and filtering all live in
//  `StationRepository` one layer up.
//

import Foundation
import MapKit
import RxSwift

protocol StationService: AnyObject {
    /// Stations within `region`.
    func fetchStations(in region: MKCoordinateRegion) -> Single<[Station]>
    /// Live status keyed by portID for one location.
    func fetchLiveStatus(locationID: String) -> Single<[String: PortStatus]>
}

final class ChargeHubStationService: StationService {

    private let apiClient: APIClient
    private let config: APIConfig

    init(apiClient: APIClient, config: APIConfig = .default) {
        self.apiClient = apiClient
        self.config = config
    }

    func fetchStations(in region: MKCoordinateRegion) -> Single<[Station]> {
        guard config.hasChargeHubCredentials else {
            return .error(APIError.missingCredentials)
        }
        let route = ChargeHubEndpoint.locations(
            region: region,
            apiKey: config.chargeHubAPIKey,
            limit: 200
        )
        // The Locations endpoint returns a bare JSON array.
        return apiClient.request(route, as: [ChargeHubStationDTO].self)
            .map { $0.compactMap { $0.toDomain() } }
    }

    func fetchLiveStatus(locationID: String) -> Single<[String: PortStatus]> {
        guard config.hasChargeHubCredentials else {
            return .error(APIError.missingCredentials)
        }
        let route = ChargeHubEndpoint.status(
            locationID: locationID,
            apiKey: config.chargeHubAPIKey
        )
        return apiClient.request(route, as: ChargeHubStatusResponse.self)
            .map { $0.statusByPortID }
    }
}

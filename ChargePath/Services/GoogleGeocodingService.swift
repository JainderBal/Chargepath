//
//  GoogleGeocodingService.swift
//  ChargePath
//
//  `GeocodingService` backed by the Google Geocoding REST API instead of
//  `CLGeocoder`. Same protocol as `AppleGeocodingService` (kept in
//  `GeocodingService.swift`), so `RouteRepository` doesn't know which one it
//  has.
//

import Foundation
import CoreLocation
import RxSwift

final class GoogleGeocodingService: GeocodingService {

    private let apiClient: APIClient
    private let config: APIConfig

    init(apiClient: APIClient, config: APIConfig = .default) {
        self.apiClient = apiClient
        self.config = config
    }

    func coordinate(for query: String) -> Single<CLLocationCoordinate2D> {
        guard config.hasGoogleMapsCredentials else { return .error(GeocodingError.notFound) }
        let route = GoogleDirectionsEndpoint.geocode(query: query, apiKey: config.googleMapsAPIKey)
        return apiClient.request(route, as: GoogleGeocodeResponse.self)
            .flatMap { response in
                guard let coordinate = response.firstCoordinate else {
                    return .error(GeocodingError.notFound)
                }
                return .just(coordinate)
            }
    }
}

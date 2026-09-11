//
//  GoogleRouteDirectionsService.swift
//  ChargePath
//
//  `RouteDirectionsService` backed by the Google Directions REST API instead
//  of `MKDirections`. Same protocol as `MapKitDirectionsService` (kept in
//  `RouteDirectionsService.swift`), so `RouteRepository`'s charging-stop
//  insertion runs unchanged regardless of which one is wired in.
//  `departure_time=now` on the request makes the ETA traffic-aware.
//

import Foundation
import CoreLocation
import RxSwift

final class GoogleRouteDirectionsService: RouteDirectionsService {

    private let apiClient: APIClient
    private let config: APIConfig

    init(apiClient: APIClient, config: APIConfig = .default) {
        self.apiClient = apiClient
        self.config = config
    }

    func directions(from origin: CLLocationCoordinate2D,
                    to destination: CLLocationCoordinate2D) -> Single<DirectionsResult> {
        guard config.hasGoogleMapsCredentials else { return .error(DirectionsError.noRoute) }
        let route = GoogleDirectionsEndpoint.directions(
            origin: origin, destination: destination, apiKey: config.googleMapsAPIKey
        )
        return apiClient.request(route, as: GoogleDirectionsResponse.self)
            .flatMap { response in
                guard let result = response.toDirectionsResult() else {
                    return .error(DirectionsError.noRoute)
                }
                return .just(result)
            }
    }
}

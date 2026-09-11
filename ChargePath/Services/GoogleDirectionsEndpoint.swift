//
//  GoogleDirectionsEndpoint.swift
//  ChargePath
//
//  Google Maps Platform REST calls the Route Planner makes, as
//  `URLRequestConvertible` — the same API-key-restricted project as the
//  Navigation SDK (`GOOGLE_MAPS_API_KEY`), just the plain Geocoding and
//  Directions APIs rather than the SDK.
//
//    • Geocoding:  GET …/geocode/json?address={query}&key={key}
//    • Directions: GET …/directions/json?origin={lat,lng}&destination={lat,lng}
//                  &mode=driving&departure_time=now&key={key}
//                  (`departure_time=now` is what makes the ETA traffic-aware)
//

import Foundation
import Alamofire
import CoreLocation

enum GoogleDirectionsEndpoint: URLRequestConvertible {

    case geocode(query: String, apiKey: String)
    case directions(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, apiKey: String)

    private var path: String {
        switch self {
        case .geocode:    return "geocode/json"
        case .directions: return "directions/json"
        }
    }

    private var apiKey: String {
        switch self {
        case let .geocode(_, key): return key
        case let .directions(_, _, key): return key
        }
    }

    private var queryItems: [URLQueryItem] {
        switch self {
        case let .geocode(query, _):
            return [URLQueryItem(name: "address", value: query)]
        case let .directions(origin, destination, _):
            return [
                URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
                URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
                URLQueryItem(name: "mode", value: "driving"),
                URLQueryItem(name: "departure_time", value: "now")
            ]
        }
    }

    func asURLRequest() throws -> URLRequest {
        let base = APIConfig.default.googleMapsBaseURL
        var components = URLComponents(
            url: base.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems + [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

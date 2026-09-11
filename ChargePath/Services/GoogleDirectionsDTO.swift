//
//  GoogleDirectionsDTO.swift
//  ChargePath
//
//  Wire models for the Google Geocoding + Directions REST responses.
//

import Foundation
import CoreLocation

// MARK: - Geocoding

struct GoogleGeocodeResponse: Decodable {
    let results: [GoogleGeocodeResult]
    let status: String

    var firstCoordinate: CLLocationCoordinate2D? {
        results.first?.geometry.location.coordinate
    }
}

struct GoogleGeocodeResult: Decodable {
    let geometry: GoogleGeocodeGeometry
}

struct GoogleGeocodeGeometry: Decodable {
    let location: GoogleLatLng
}

struct GoogleLatLng: Decodable {
    let lat: Double
    let lng: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

// MARK: - Directions

struct GoogleDirectionsResponse: Decodable {
    let routes: [GoogleDirectionsRoute]
    let status: String

    /// The app only ever requests a single origin→destination leg.
    func toDirectionsResult() -> DirectionsResult? {
        guard let route = routes.first, let leg = route.legs.first else { return nil }
        let polyline = GooglePolylineDecoder.decode(route.overviewPolyline.points)
        guard polyline.count > 1 else { return nil }
        let travelTime = leg.durationInTraffic?.value ?? leg.duration.value
        return DirectionsResult(
            polyline: polyline,
            distanceMeters: Double(leg.distance.value),
            expectedTravelTimeSeconds: Double(travelTime)
        )
    }
}

struct GoogleDirectionsRoute: Decodable {
    let overviewPolyline: GoogleOverviewPolyline
    let legs: [GoogleDirectionsLeg]

    private enum CodingKeys: String, CodingKey {
        case overviewPolyline = "overview_polyline"
        case legs
    }
}

struct GoogleOverviewPolyline: Decodable {
    let points: String
}

struct GoogleDirectionsLeg: Decodable {
    let distance: GoogleValueText
    let duration: GoogleValueText
    /// Only present when the request carries `departure_time` — this is what
    /// makes the ETA traffic-aware rather than a free-flow estimate.
    let durationInTraffic: GoogleValueText?

    private enum CodingKeys: String, CodingKey {
        case distance, duration
        case durationInTraffic = "duration_in_traffic"
    }
}

struct GoogleValueText: Decodable {
    let value: Int
}

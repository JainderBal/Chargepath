//
//  RoutePlan.swift
//  ChargePath
//
//  Trip input + computed charging itinerary for the Route Planner screen.
//

import CoreLocation
import Foundation

/// What the user typed / selected on the Route Planner input screen.
struct TripQuery: Equatable {
    var originText: String
    var destinationText: String
    /// Usable range for planning, km. Pre-filled from the selected vehicle but
    /// editable, hence carried on the query rather than read live.
    var vehicleRangeKm: Int
    var vehicleConnector: Connector
}

/// Result of planning: the drawn route plus the stops we inserted.
struct RoutePlan: Equatable {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    /// Full driving polyline, for drawing on the results map.
    let routeCoordinates: [CLLocationCoordinate2D]
    let totalDistanceKm: Double
    let stops: [ChargingStop]
    /// Driving time from MKDirections, seconds — traffic-aware, charging time
    /// not included.
    var driveTimeSeconds: TimeInterval = 0
    /// true when geocoding / directions failed and this is the offline
    /// illustrative plan rather than a real MKDirections route.
    var isEstimate: Bool = false

    /// Driving time alone, e.g. "4 h 12 min".
    var driveTimeText: String { Self.durationText(driveTimeSeconds) }

    /// Driving + every planned charging stop, e.g. "4 h 46 min".
    var totalTripText: String {
        let chargeSeconds = stops.reduce(0) { $0 + Double($1.estimatedChargeMinutes) * 60 }
        return Self.durationText(driveTimeSeconds + chargeSeconds)
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours) h \(minutes) min" : "\(minutes) min"
    }

    static func == (lhs: RoutePlan, rhs: RoutePlan) -> Bool {
        lhs.totalDistanceKm == rhs.totalDistanceKm
            && lhs.stops == rhs.stops
            && lhs.driveTimeSeconds == rhs.driveTimeSeconds
            && lhs.isEstimate == rhs.isEstimate
    }
}

/// One inserted charging stop along the route.
struct ChargingStop: Identifiable, Equatable {
    var id: String { station.id }
    /// 1-based position along the trip.
    let index: Int
    let station: Station
    /// Distance from origin to this stop, km.
    let distanceIntoTripKm: Double
    /// Estimated battery % on arrival at this stop.
    let arrivalStateOfChargePercent: Int
    /// Estimated minutes plugged in here.
    let estimatedChargeMinutes: Int

    /// Mockup sub-line: "118 km in · 180 kW · arrive 41%".
    var detailText: String {
        "\(Int(distanceIntoTripKm)) km in · \(station.maxPowerKW) kW · arrive \(arrivalStateOfChargePercent)%"
    }
}

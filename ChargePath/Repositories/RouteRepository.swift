//
//  RouteRepository.swift
//  ChargePath
//
//  Turns a TripQuery into a RoutePlan: geocode endpoints → real driving
//  polyline (MKDirections) → greedy insertion of charging stops so the pack
//  never drops below a 15% reserve (the mockup's planHint).
//
//  If geocoding or directions fail (e.g. offline during review), it returns a
//  clearly-labelled demo plan built from seed stations so the results screen
//  still has something to show.
//

import Foundation
import CoreLocation
import MapKit
import RxSwift

protocol RouteRepository: AnyObject {
    func planTrip(_ query: TripQuery) -> Single<RoutePlan>
}

final class DefaultRouteRepository: RouteRepository {

    /// Battery reserve we never plan below.
    private let reserveFraction = 0.15
    /// Charge target we assume at each stop (fast chargers taper past this).
    private let chargeTargetFraction = 0.90
    /// Rough energy use — used only to estimate charge minutes.
    private let kmPerKWh = 5.0

    private let geocoder: GeocodingService
    private let directions: RouteDirectionsService
    private let stationRepository: StationRepository

    init(geocoder: GeocodingService,
         directions: RouteDirectionsService,
         stationRepository: StationRepository) {
        self.geocoder = geocoder
        self.directions = directions
        self.stationRepository = stationRepository
    }

    func planTrip(_ query: TripQuery) -> Single<RoutePlan> {
        let origin = geocoder.coordinate(for: query.originText)
        let destination = geocoder.coordinate(for: query.destinationText)

        return Single.zip(origin, destination)
            .flatMap { [directions] from, to in
                directions.directions(from: from, to: to)
                    .map { (from, to, $0) }
            }
            .map { [weak self] from, to, result -> RoutePlan in
                guard let self else {
                    return RoutePlan(origin: from, destination: to,
                                     routeCoordinates: result.polyline,
                                     totalDistanceKm: result.distanceMeters / 1000,
                                     stops: [],
                                     driveTimeSeconds: result.expectedTravelTimeSeconds)
                }
                return self.buildPlan(from: from, to: to, directions: result, query: query)
            }
            // CLGeocoder / MKDirections can hang (no callback) rather than
            // erroring — cap the wait so the screen never stays "planning".
            .timeout(.seconds(15), scheduler: MainScheduler.instance)
            .catch { [weak self] _ in
                .just(self?.demoPlan(for: query) ?? RoutePlan(
                    origin: .init(), destination: .init(),
                    routeCoordinates: [], totalDistanceKm: 0, stops: []))
            }
    }

    // MARK: - Greedy stop placement

    private func buildPlan(from: CLLocationCoordinate2D,
                           to: CLLocationCoordinate2D,
                           directions: DirectionsResult,
                           query: TripQuery) -> RoutePlan {

        let totalKm = directions.distanceMeters / 1000
        let range = Double(query.vehicleRangeKm)
        let candidates = compatibleStations(for: query.vehicleConnector)

        // Distance we can cover from a given starting state-of-charge.
        func drivable(fromSOC soc: Double) -> Double { (soc - reserveFraction) * range }

        var stops: [ChargingStop] = []
        var distanceAtLastCharge = 0.0
        var socAtLastCharge = 1.0            // leave home full
        let cumulative = cumulativeDistancesKm(along: directions.polyline)

        var legBudget = drivable(fromSOC: socAtLastCharge)

        // Walk the polyline; whenever the remaining trip past `legBudget`
        // still has road left, drop a stop near the budget limit.
        var guardCounter = 0
        while distanceAtLastCharge + legBudget < totalKm && guardCounter < 12 {
            guardCounter += 1
            let targetDistance = distanceAtLastCharge + legBudget * 0.9  // small safety margin
            let pointOnRoute = coordinate(atKm: targetDistance,
                                          polyline: directions.polyline,
                                          cumulative: cumulative)

            guard let station = nearestStation(to: pointOnRoute, from: candidates, excluding: stops) else {
                break
            }

            let legKm = targetDistance - distanceAtLastCharge
            let arrivalSOC = max(reserveFraction, socAtLastCharge - legKm / range)
            let stop = ChargingStop(
                index: stops.count + 1,
                station: station,
                distanceIntoTripKm: targetDistance,
                arrivalStateOfChargePercent: Int((arrivalSOC * 100).rounded()),
                estimatedChargeMinutes: chargeMinutes(
                    fromSOC: arrivalSOC, station: station, range: range)
            )
            stops.append(stop)

            distanceAtLastCharge = targetDistance
            socAtLastCharge = chargeTargetFraction
            legBudget = drivable(fromSOC: socAtLastCharge)
        }

        return RoutePlan(
            origin: from,
            destination: to,
            routeCoordinates: directions.polyline,
            totalDistanceKm: totalKm,
            stops: stops,
            driveTimeSeconds: directions.expectedTravelTimeSeconds
        )
    }

    /// Candidate pool for stops: everything the station repository has cached,
    /// unioned with the seed set (the cache is region-scoped, so it may not
    /// cover the whole corridor), keeping only connector-compatible stations.
    private func compatibleStations(for connector: Connector) -> [Station] {
        var byID: [String: Station] = [:]
        for station in stationRepository.cachedStations + StationSeed.stations {
            byID[station.id] = station
        }
        return byID.values.filter {
            $0.connectors.contains(connector) || $0.connectors.contains(.unknown)
        }
    }

    private func nearestStation(to point: CLLocationCoordinate2D,
                                from stations: [Station],
                                excluding used: [ChargingStop]) -> Station? {
        let usedIDs = Set(used.map(\.station.id))
        let target = CLLocation(latitude: point.latitude, longitude: point.longitude)
        return stations
            .filter { !usedIDs.contains($0.id) }
            .min { a, b in
                target.distance(from: CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude))
                    < target.distance(from: CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude))
            }
    }

    private func chargeMinutes(fromSOC soc: Double, station: Station, range: Double) -> Int {
        let batteryKWh = range / kmPerKWh
        let energyNeeded = (chargeTargetFraction - soc) * batteryKWh          // kWh
        let power = Double(max(station.maxPowerKW, 50))
        let minutes = energyNeeded / power * 60 * 1.15                         // taper fudge
        return max(10, Int(minutes.rounded()))
    }

    // MARK: - Polyline helpers

    private func cumulativeDistancesKm(along polyline: [CLLocationCoordinate2D]) -> [Double] {
        var total = 0.0
        var out: [Double] = polyline.isEmpty ? [] : [0]
        for i in 1..<max(polyline.count, 1) {
            let a = CLLocation(latitude: polyline[i - 1].latitude, longitude: polyline[i - 1].longitude)
            let b = CLLocation(latitude: polyline[i].latitude, longitude: polyline[i].longitude)
            total += a.distance(from: b) / 1000
            out.append(total)
        }
        return out
    }

    private func coordinate(atKm km: Double,
                            polyline: [CLLocationCoordinate2D],
                            cumulative: [Double]) -> CLLocationCoordinate2D {
        guard let last = cumulative.last, last > 0 else {
            return polyline.first ?? CLLocationCoordinate2D()
        }
        guard km > 0 else { return polyline.first! }
        guard km < last else { return polyline.last! }
        // First vertex at or beyond `km`.
        let idx = cumulative.firstIndex { $0 >= km } ?? (polyline.count - 1)
        return polyline[idx]
    }

    // MARK: - Offline demo fallback

    private func demoPlan(for query: TripQuery) -> RoutePlan {
        let from = CLLocationCoordinate2D(latitude: 45.5310, longitude: -73.6200) // Villeray-ish
        let to = CLLocationCoordinate2D(latitude: 45.3060, longitude: -72.6500)   // Bromont, QC
        let line = [from,
                    CLLocationCoordinate2D(latitude: 45.45, longitude: -73.30),
                    CLLocationCoordinate2D(latitude: 45.38, longitude: -72.95),
                    to]
        let picks = Array(StationSeed.stations.suffix(2))
        let stops = picks.enumerated().map { i, station in
            ChargingStop(
                index: i + 1,
                station: station,
                distanceIntoTripKm: Double((i + 1) * 120),
                arrivalStateOfChargePercent: 40 - i * 20,
                estimatedChargeMinutes: 22 + i * 12
            )
        }
        return RoutePlan(origin: from, destination: to,
                         routeCoordinates: line,
                         totalDistanceKm: 412, stops: stops,
                         driveTimeSeconds: 4.5 * 3600,
                         isEstimate: true)
    }
}

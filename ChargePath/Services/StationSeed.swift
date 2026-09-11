//
//  StationSeed.swift
//  ChargePath
//
//  Offline sample data. Used by `StationRepository` when the ChargeHub API is
//  unkeyed / unreachable, or (on the free demo tier) returns fewer stations
//  than this set.
//
//  The station data lives in `Resources/chargehub-locations-sample.json` and
//  `chargehub-status-sample.json` in the EXACT shape ChargeHub's
//  `/demo/locations` and `/demo/status` endpoints return, and is decoded here
//  through the very same DTO pipeline (`ChargeHubStationDTO`,
//  `ChargeHubStatusResponse`) that `ChargeHubStationService` uses for live
//  data. So the whole Map / Station Detail / Route flow is exercised against
//  ChargeHub-shaped JSON even with no API key.
//

import Foundation
import CoreLocation

enum StationSeed {

    static let vehicles: [Vehicle] = [
        Vehicle(id: "v1", name: "Aurora EV5",    connector: .nacs,  rangeKm: 402),
        Vehicle(id: "v2", name: "Kestrel Sport", connector: .ccs,   rangeKm: 355),
        Vehicle(id: "v3", name: "Meridian Van",  connector: .ccs,   rangeKm: 288),
        Vehicle(id: "v4", name: "Lumen City",    connector: .j1772, rangeKm: 210)
    ]

    static let stations: [Station] = loadStations()

    /// Ids of the two stations bookmarked on first launch (Plateau Garage,
    /// Rosemont Co-op) — matches the design mockup.
    static let defaultBookmarkedIDs: Set<String> = ["1002", "1004"]

    // MARK: - Loading (identical path to the live service)

    private static func loadStations() -> [Station] {
        guard
            let url = Bundle.main.url(forResource: "chargehub-locations-sample", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let dtos = try? JSONDecoder().decode([ChargeHubStationDTO].self, from: data)
        else {
            assertionFailure("chargehub-locations-sample.json missing or malformed")
            return fallback
        }

        let stations = dtos.compactMap { $0.toDomain() }
        return merge(liveStatusInto: stations)
    }

    /// Same merge `StationRepository.refreshLiveStatus(for:)` performs, but from
    /// the bundled status sample.
    private static func merge(liveStatusInto stations: [Station]) -> [Station] {
        guard
            let url = Bundle.main.url(forResource: "chargehub-status-sample", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let response = try? JSONDecoder().decode(ChargeHubStatusResponse.self, from: data)
        else {
            return stations
        }
        let byPortID = response.statusByPortID
        return stations.map { station in
            var updated = station
            updated.ports = station.ports.map { port in
                var port = port
                if let live = byPortID[port.id] { port.status = live }
                return port
            }
            return updated
        }
    }

    /// Absolute-minimum data if the bundled resources can't be read.
    private static let fallback: [Station] = [
        Station(
            id: "1001", name: "Marché Central", address: "1500 Rue Sauvé O",
            coordinate: .init(latitude: 45.5462, longitude: -73.6579),
            connectors: [.ccs, .nacs], priceText: "$0.38 / kWh",
            ports: [
                ChargingPort(id: "100101", label: "A1", connector: .nacs,
                             powerKW: 250, status: .available, note: nil)
            ]
        )
    ]
}

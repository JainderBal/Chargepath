//
//  Vehicle.swift
//  ChargePath
//
//  Mirrors the mockup's VEHICLES data (id, name, sub, conn, range).
//

struct Vehicle: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    /// The plug this car charges with — drives connector-compatibility filtering.
    let connector: Connector
    /// Rated range in kilometres (used to auto-fill the Route Planner).
    let rangeKm: Int

    /// Secondary line shown under the name, e.g. "NACS · 402 km range".
    var subtitle: String {
        "\(connector.displayName) · \(rangeKm) km range"
    }
}

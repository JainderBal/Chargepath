//
//  Station.swift
//  ChargePath
//
//  Domain model for a charging location and its ports. This is the shape the
//  UI and ViewModels work with — the ChargeHub API DTOs (Services layer) are
//  mapped into this and never leak upward.
//
//  Field set mirrors the mockup's STATIONS mock objects (name, addr, dist,
//  conns, rate, ports[n/conn/kw/status/note]) but coordinates are real
//  latitude/longitude instead of the mockup's decorative x/y percentages.
//

import CoreLocation

struct Station: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    /// Distinct connector standards available anywhere on site (badge row).
    let connectors: [Connector]
    /// Advertised energy price, pre-formatted for display (e.g. "$0.38 / kWh").
    let priceText: String?
    /// `var` so the repository can merge live status onto a cached copy.
    var ports: [ChargingPort]
    /// Straight-line distance from the user, metres. Filled in by the
    /// repository once a user location is known; nil until then.
    var distanceFromUser: CLLocationDistance?

    var availablePortCount: Int {
        ports.filter { $0.status == .available }.count
    }

    var isFullyOffline: Bool {
        !ports.isEmpty && ports.allSatisfy { $0.status == .offline }
    }

    /// Highest port power on site, kW — used by the "charging speed" filter.
    var maxPowerKW: Int {
        ports.map(\.powerKW).max() ?? 0
    }

    static func == (lhs: Station, rhs: Station) -> Bool {
        lhs.id == rhs.id
            && lhs.ports == rhs.ports
            && lhs.distanceFromUser == rhs.distanceFromUser
    }
}

struct ChargingPort: Identifiable, Equatable {
    let id: String
    /// Short bay label from the mockup ("A1", "B2", …).
    let label: String
    let connector: Connector
    let powerKW: Int
    var status: PortStatus
    /// Free-text hint ("Pull-through bay", "Free in ~18 min", …).
    let note: String?

    var powerText: String { "\(powerKW) kW" }
}

/// Live availability of a single port. Raw values line up with ChargeHub's
/// documented Status endpoint `StatusCode` integers.
enum PortStatus: Int, Codable, Equatable {
    case available = 1
    case inUse = 2
    case offline = 3
    case unknown = 0

    /// Matches the mockup's English status strings.
    var displayName: String {
        switch self {
        case .available: return "Available"
        case .inUse: return "In use"
        case .offline: return "Offline"
        case .unknown: return "—"
        }
    }

    init(apiValue raw: String) {
        switch raw.lowercased() {
        case "available", "free", "open": self = .available
        case "in use", "inuse", "busy", "charging", "occupied": self = .inUse
        case "offline", "unavailable", "out of service", "fault": self = .offline
        default: self = .unknown
        }
    }
}

//
//  ChargeHubDTO.swift
//  ChargePath
//
//  Wire models for ChargeHub responses + mapping into domain `Station`s.
//  DTOs stay confined to the Services layer; callers only ever see `Station`.
//
//  Shapes match the "Demo - POI" API definition on developer.chargehub.com.
//  Decoding is lenient — undocumented fields come and go, and `Connectors`
//  arrives as either ["A","B"] or [["A","B"]] depending on the endpoint.
//

import Foundation
import CoreLocation

// MARK: - Locations (bare JSON array of these)

struct ChargeHubStationDTO: Decodable {
    let locID: Int
    let locName: String?
    let streetAddress: String?
    let latitude: Double?
    let longitude: Double?
    let ports: [ChargeHubPortDTO]?

    private enum CodingKeys: String, CodingKey {
        case locID = "LocID"
        case locName = "LocName"
        case streetAddress = "StreetAddress"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case ports = "Ports"
    }

    /// nil when the row has no usable coordinate — such rows are dropped.
    func toDomain() -> Station? {
        guard let latitude, let longitude else { return nil }
        let mappedPorts = (ports ?? []).enumerated().map { index, dto in
            dto.toDomain(fallbackIndex: index)
        }
        let connectors = Array(Set(mappedPorts.map(\.connector)))
            .sorted { $0.rawValue < $1.rawValue }
        return Station(
            id: String(locID),
            name: locName ?? "Charging station",
            address: streetAddress ?? "",
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            connectors: connectors.isEmpty ? [.unknown] : connectors,
            priceText: (ports ?? []).compactMap(\.chargingCostDisplay).first,
            ports: mappedPorts,
            distanceFromUser: nil
        )
    }
}

struct ChargeHubPortDTO: Decodable {
    let portID: Int?
    let level: Int?
    let displayName: String?
    let powerKW: Double?
    let chargingCostDisplay: String?
    /// Flattened connector names, e.g. ["Chademo", "J1772 Combo"].
    let connectorNames: [String]

    private enum CodingKeys: String, CodingKey {
        case portID = "PortID"
        case level = "Level"
        case displayName = "DisplayName"
        case powerKW = "KW"
        case chargingCostDisplay = "ChargingCostDisplay"
        case connectors = "Connectors"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        portID = try c.decodeIfPresent(Int.self, forKey: .portID)
        level = try c.decodeIfPresent(Int.self, forKey: .level)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        powerKW = try c.decodeIfPresent(Double.self, forKey: .powerKW)
        chargingCostDisplay = try c.decodeIfPresent(String.self, forKey: .chargingCostDisplay)

        // `Connectors` is [["A","B"]] on some endpoints, ["A","B"] on others.
        if let nested = try? c.decode([[String]].self, forKey: .connectors) {
            connectorNames = nested.flatMap { $0 }
        } else if let flat = try? c.decode([String].self, forKey: .connectors) {
            connectorNames = flat
        } else {
            connectorNames = []
        }
    }

    func toDomain(fallbackIndex: Int) -> ChargingPort {
        let connector = connectorNames
            .map { Connector(apiValue: $0) }
            .first { $0 != .unknown } ?? .unknown
        let label = (displayName?.isEmpty == false ? displayName! : nil)
            ?? portID.map { "#\($0)" }
            ?? "P\(fallbackIndex + 1)"
        return ChargingPort(
            id: portID.map(String.init) ?? "p\(fallbackIndex + 1)",
            label: label,
            connector: connector,
            powerKW: Int((powerKW ?? 0).rounded()),
            // The Locations payload carries no live status — the Status API
            // refines it. `.unknown` reads as "not offline" on the map.
            status: .unknown,
            note: nil
        )
    }
}

// MARK: - Status

/// ChargeHub's status row: `{ LocID, PortID, StatusCode, StatusTime }`.
/// Accepts a bare array or `{ "Ports": [ … ] }`. (Confirm the real shape
/// against the portal's Status operation.)
struct ChargeHubStatusResponse: Decodable {
    let entries: [ChargeHubStatusEntry]

    init(from decoder: Decoder) throws {
        if let array = try? decoder.singleValueContainer().decode([ChargeHubStatusEntry].self) {
            entries = array
            return
        }
        struct Wrapper: Decodable {
            let ports: [ChargeHubStatusEntry]?
            private enum CodingKeys: String, CodingKey { case ports = "Ports" }
        }
        entries = (try? Wrapper(from: decoder).ports) ?? []
    }

    /// portID → live status, ready to merge onto a cached `Station`.
    var statusByPortID: [String: PortStatus] {
        Dictionary(entries.map { (String($0.portID), $0.status) }) { _, latest in latest }
    }
}

struct ChargeHubStatusEntry: Decodable {
    let locID: Int
    let portID: Int
    let statusCode: Int

    private enum CodingKeys: String, CodingKey {
        case locID = "LocID"
        case portID = "PortID"
        case statusCode = "StatusCode"
    }

    var status: PortStatus { PortStatus(rawValue: statusCode) ?? .unknown }
}

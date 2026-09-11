//
//  OpenChargeMapDTO.swift
//  ChargePath
//
//  Wire models for Open Charge Map POI responses + mapping into domain
//  `Station`s. Like `ChargeHubDTO`, the DTOs stay confined to the Services
//  layer and callers only ever see `Station`.
//
//  Shapes match the `/v3/poi` response with `verbose=false`. Decoding is
//  lenient — OCM is community-edited, so almost every field can be absent.
//

import Foundation
import CoreLocation

// MARK: - POI (bare JSON array of these)

struct OCMPoiDTO: Decodable {
    let id: Int
    let addressInfo: OCMAddressInfoDTO?
    let connections: [OCMConnectionDTO]?
    let operatorInfo: OCMOperatorDTO?
    let usageCost: String?
    let statusType: OCMStatusTypeDTO?

    private enum CodingKeys: String, CodingKey {
        case id = "ID"
        case addressInfo = "AddressInfo"
        case connections = "Connections"
        case operatorInfo = "OperatorInfo"
        case usageCost = "UsageCost"
        case statusType = "StatusType"
    }

    /// nil when the row carries no usable coordinate — such rows are dropped.
    func toDomain() -> Station? {
        guard
            let addressInfo,
            let latitude = addressInfo.latitude,
            let longitude = addressInfo.longitude
        else { return nil }

        let siteOperational = statusType?.isOperational
        let mappedPorts = (connections ?? []).enumerated().map { index, dto in
            dto.toDomain(fallbackIndex: index, siteOperational: siteOperational)
        }
        let connectors = Array(Set(mappedPorts.map(\.connector)))
            .sorted { $0.rawValue < $1.rawValue }

        let name = addressInfo.title
            ?? operatorInfo?.title
            ?? "Charging station"

        return Station(
            id: String(id),
            name: name,
            address: addressInfo.singleLine,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            connectors: connectors.isEmpty ? [.unknown] : connectors,
            priceText: usageCost?.isEmpty == false ? usageCost : nil,
            ports: mappedPorts,
            distanceFromUser: nil
        )
    }
}

struct OCMAddressInfoDTO: Decodable {
    let title: String?
    let addressLine1: String?
    let town: String?
    let stateOrProvince: String?
    let latitude: Double?
    let longitude: Double?

    private enum CodingKeys: String, CodingKey {
        case title = "Title"
        case addressLine1 = "AddressLine1"
        case town = "Town"
        case stateOrProvince = "StateOrProvince"
        case latitude = "Latitude"
        case longitude = "Longitude"
    }

    /// "1 Rue X, Montréal, QC" from whichever parts are present.
    var singleLine: String {
        [addressLine1, town, stateOrProvince]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: ", ")
    }
}

struct OCMConnectionDTO: Decodable {
    let connectionType: OCMTitleDTO?
    let level: OCMTitleDTO?
    let powerKW: Double?
    let quantity: Int?
    let statusType: OCMStatusTypeDTO?

    private enum CodingKeys: String, CodingKey {
        case connectionType = "ConnectionType"
        case level = "Level"
        case powerKW = "PowerKW"
        case quantity = "Quantity"
        case statusType = "StatusType"
    }

    /// One domain `ChargingPort` per connection group. OCM reports no live
    /// occupancy, so `status` only ever distinguishes operational from not.
    func toDomain(fallbackIndex: Int, siteOperational: Bool?) -> ChargingPort {
        let connector = Connector(apiValue: connectionType?.title ?? "")
        let label: String = {
            let base = connector == .unknown
                ? (connectionType?.title ?? "Port \(fallbackIndex + 1)")
                : connector.displayName
            if let quantity, quantity > 1 { return "\(base) ×\(quantity)" }
            return base
        }()
        let operational = statusType?.isOperational ?? siteOperational
        let status: PortStatus
        switch operational {
        case .some(true):  status = .available
        case .some(false): status = .offline
        case .none:        status = .unknown
        }
        return ChargingPort(
            id: "c\(fallbackIndex + 1)",
            label: label,
            connector: connector,
            powerKW: Int((powerKW ?? 0).rounded()),
            status: status,
            note: level?.title
        )
    }
}

struct OCMTitleDTO: Decodable {
    let title: String?
    private enum CodingKeys: String, CodingKey { case title = "Title" }
}

struct OCMOperatorDTO: Decodable {
    let title: String?
    private enum CodingKeys: String, CodingKey { case title = "Title" }
}

struct OCMStatusTypeDTO: Decodable {
    let isOperational: Bool?
    private enum CodingKeys: String, CodingKey { case isOperational = "IsOperational" }
}

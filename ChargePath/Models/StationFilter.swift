//
//  StationFilter.swift
//  ChargePath
//
//  Value type describing everything the Map screen + Filter sheet can narrow
//  by. Ported directly from the mockup's filter state (seg, filters{},
//  compatOnly, openNow, avail, power, radius) and its `visible()` predicate.
//

import Foundation

struct StationFilter: Equatable {

    /// "All stations" vs "Bookmarked" segmented control on the Map screen.
    enum Segment: Equatable { case all, bookmarked }

    /// Availability options in the filter sheet.
    enum Availability: Equatable { case any, oneFree, twoFree }

    /// Charging-speed options in the filter sheet.
    enum Power: Equatable { case any, level2, fast, ultra }

    var segment: Segment = .all
    /// Connectors currently allowed. Default = all known plugs enabled.
    var connectors: Set<Connector> = [.ccs, .nacs, .j1772]
    var availability: Availability = .any
    var power: Power = .any
    /// Search radius in kilometres. 100 is treated as "Any" in the UI.
    var radiusKm: Int = 25
    /// Only show stations whose connectors fit the selected vehicle.
    var compatibleOnly: Bool = false
    /// Hide stations where every port is offline.
    var hideOffline: Bool = false
    /// Free-text query typed into the search bar (name / address contains).
    var query: String = ""

    static let `default` = StationFilter()

    /// Count of "non-default" choices — drives the little dot on the filter
    /// button (mockup `activeFilterCount`).
    var activeAdjustmentCount: Int {
        var count = 0
        if connectors != StationFilter.default.connectors { count += 1 }
        if availability != .any { count += 1 }
        if power != .any { count += 1 }
        if radiusKm != StationFilter.default.radiusKm { count += 1 }
        if compatibleOnly { count += 1 }
        if hideOffline { count += 1 }
        return count
    }

    /// Applies every rule to one station. `vehicleConnector` is required only
    /// when `compatibleOnly` is on; `distanceKm` when a user location exists.
    func matches(_ station: Station,
                 vehicleConnector: Connector?,
                 isBookmarked: Bool,
                 distanceKm: Double?) -> Bool {

        if segment == .bookmarked && !isBookmarked { return false }

        if compatibleOnly, let vc = vehicleConnector, !station.connectors.contains(vc) {
            return false
        }

        // Connector filter only bites once at least one plug is disabled.
        if connectors.count < StationFilter.default.connectors.count,
           !station.connectors.contains(where: { connectors.contains($0) }) {
            return false
        }

        switch availability {
        case .any: break
        case .oneFree: if station.availablePortCount < 1 { return false }
        case .twoFree: if station.availablePortCount < 2 { return false }
        }

        switch power {
        case .any: break
        case .level2: if station.maxPowerKW > 22 { return false }
        case .fast: if station.maxPowerKW < 150 { return false }
        case .ultra: if station.maxPowerKW < 250 { return false }
        }

        if let distanceKm, distanceKm > Double(radiusKm) { return false }

        if hideOffline && station.isFullyOffline { return false }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            let haystack = (station.name + " " + station.address).lowercased()
            if !haystack.contains(q) { return false }
        }

        return true
    }
}

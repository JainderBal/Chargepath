//
//  Connector.swift
//  ChargePath
//
//  EV plug standards the app understands. The mockup only ever references
//  three (CCS, NACS, J1772); `unknown` is a decode-safety net for whatever
//  the ChargeHub API returns that we don't map yet.
//

import Foundation

enum Connector: String, Codable, CaseIterable, Hashable {
    case ccs = "CCS"
    case nacs = "NACS"
    case j1772 = "J1772"
    case unknown

    /// Human label for badges. Kept identical to the mockup's copy.
    var displayName: String {
        switch self {
        case .ccs: return "CCS"
        case .nacs: return "NACS"
        case .j1772: return "J1772"
        case .unknown: return "—"
        }
    }

    /// Lenient parsing: ChargeHub / Open Charge Map / user input all use many
    /// spellings for the same plug. Substring matching handles compound names
    /// like "J1772 Combo" (= CCS) and OCM's "CCS (Type 1)" / "Type 1 (J1772)"
    /// / "Tesla (Model S/X)" — order matters: check NACS, then Combo/CCS, then
    /// plain J1772. OCM "CHAdeMO" / "Type 2" have no case here and fall through
    /// to `.unknown`.
    init(apiValue raw: String) {
        let key = raw.uppercased()
        if key.contains("NACS") || key.contains("TESLA")
            || key.contains("SUPERCHARGER") || key.contains("TPC") {
            self = .nacs
        } else if key.contains("COMBO") || key.contains("CCS") {
            self = .ccs
        } else if key.contains("J1772") || key.contains("J-1772")
            || key.contains("TYPE 1") || key.contains("TYPE1") {
            self = .j1772
        } else {
            self = .unknown
        }
    }
}

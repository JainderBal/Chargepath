//
//  AppLanguage.swift
//  ChargePath
//
//  Two-language toggle (Settings). The app ships its own string tables rather
//  than .strings files so the EN/FR copy stays a 1:1 port of the mockup's
//  `STR` object and can be switched live without relaunch.
//

enum AppLanguage: String, CaseIterable, Codable {
    case en
    case fr

    var shortLabel: String { rawValue.uppercased() }   // "EN" / "FR"

    var strings: Strings { self == .en ? .english : .french }
}

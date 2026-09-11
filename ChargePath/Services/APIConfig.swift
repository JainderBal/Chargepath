//
//  APIConfig.swift
//  ChargePath
//
//  Network configuration. Injected into the API client / services so the base
//  URL and credentials are never hard-coded mid-stack.
//

import Foundation

struct APIConfig {
    /// ChargeHub REST base. `…/demo` is the free "Demo - POI" product — a tiny
    /// fixed US sample that ignores geo parameters. Swap the path segment for
    /// the paid "Trial - POI" tier to get bounding-box queries and real
    /// coverage; `ChargeHubEndpoint` is where the params would be added.
    let chargeHubBaseURL: URL

    /// ChargeHub API key. Empty in the repo. Supply it in
    /// `Config/Secrets.xcconfig` (git-ignored) — see `Config/Secrets.example.xcconfig`.
    /// When empty, `StationRepository` serves bundled seed data instead of
    /// hitting the network.
    let chargeHubAPIKey: String

    /// Open Charge Map REST base. Community-run, openly licensed, global
    /// coverage — this is the source the live map actually uses.
    let openChargeMapBaseURL: URL

    /// Open Charge Map API key. Optional: OCM serves keyless traffic, just
    /// rate-limited. Supply it in `Config/Secrets.xcconfig` (git-ignored).
    let openChargeMapAPIKey: String

    let requestTimeout: TimeInterval

    static let `default` = APIConfig(
        chargeHubBaseURL: URL(string: "https://apiv3.chargehub.com/demo")!,
        chargeHubAPIKey: Self.resolvedChargeHubKey,
        openChargeMapBaseURL: URL(string: "https://api.openchargemap.io/v3")!,
        openChargeMapAPIKey: Self.resolvedOpenChargeMapKey,
        requestTimeout: 20
    )

    var hasChargeHubCredentials: Bool { !chargeHubAPIKey.isEmpty }
    var hasOpenChargeMapCredentials: Bool { !openChargeMapAPIKey.isEmpty }

    /// Key resolution order:
    /// 1. `CHARGEHUB_API_KEY` in Info.plist — populated at build time from the
    ///    build setting of the same name (`Config/Base.xcconfig` includes the
    ///    git-ignored `Config/Secrets.xcconfig`).
    /// 2. a `CHARGEHUB_API_KEY` environment variable (e.g. an Xcode scheme var
    ///    or `xcrun simctl launch --env`).
    private static var resolvedChargeHubKey: String {
        resolvedKey(named: "CHARGEHUB_API_KEY")
    }

    /// Same Info.plist → environment resolution as the ChargeHub key.
    private static var resolvedOpenChargeMapKey: String {
        resolvedKey(named: "OPEN_CHARGE_MAP_API_KEY")
    }

    private static func resolvedKey(named name: String) -> String {
        let fromPlist = Bundle.main.object(forInfoDictionaryKey: name) as? String ?? ""
        let fromEnv = ProcessInfo.processInfo.environment[name] ?? ""
        let key = fromPlist.isEmpty ? fromEnv : fromPlist
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

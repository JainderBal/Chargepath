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

    let requestTimeout: TimeInterval

    static let `default` = APIConfig(
        chargeHubBaseURL: URL(string: "https://apiv3.chargehub.com/demo")!,
        chargeHubAPIKey: Self.resolvedChargeHubKey,
        requestTimeout: 20
    )

    var hasChargeHubCredentials: Bool { !chargeHubAPIKey.isEmpty }

    /// Key resolution order:
    /// 1. `CHARGEHUB_API_KEY` in Info.plist — populated at build time from the
    ///    build setting of the same name (`Config/Base.xcconfig` includes the
    ///    git-ignored `Config/Secrets.xcconfig`).
    /// 2. a `CHARGEHUB_API_KEY` environment variable (e.g. an Xcode scheme var
    ///    or `xcrun simctl launch --env`).
    private static var resolvedChargeHubKey: String {
        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "CHARGEHUB_API_KEY") as? String ?? ""
        let fromEnv = ProcessInfo.processInfo.environment["CHARGEHUB_API_KEY"] ?? ""
        let key = fromPlist.isEmpty ? fromEnv : fromPlist
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

//
//  ChargingSession.swift
//  ChargePath
//
//  Models for the charging lifecycle: pick a port → confirm (pre-auth hold) →
//  a live simulated session → stop → settle the real energy cost against the
//  wallet. Everything is Test Mode: no real payment is taken.
//

import Foundation

/// Steps of the Activate sheet.
enum ActivateChargingStep: Equatable {
    case selectPort
    case confirmPayment
}

/// A charging session in progress. The "meter" (`energyKWh`) is simulated by a
/// timer in `ChargingSessionRepository`, time-compressed for the demo.
struct ActiveChargingSession: Equatable {
    let id: UUID
    let stationID: String
    let stationName: String
    let portID: String
    let portLabel: String
    let powerKW: Int
    /// Advertised energy price, $/kWh.
    let ratePerKWh: Double
    /// Flat per-session connection fee.
    let sessionFee: Double
    /// Pre-authorisation hold placed on the payment method at start.
    let holdAmount: Double
    let startedAt: Date

    /// Simulated energy delivered so far, kWh.
    var energyKWh: Double = 0
    /// Simulated elapsed charging time, seconds.
    var elapsedSeconds: TimeInterval = 0
    let isTestMode: Bool = true

    /// Cost so far = energy × rate + the session fee.
    var runningCost: Double { energyKWh * ratePerKWh + sessionFee }

    /// The session auto-stops here — a plausible top-up for this port
    /// (kept small so the time-compressed demo finishes in seconds).
    var targetEnergyKWh: Double { max(6, Double(powerKW) * 0.16) }
}

/// Final receipt once a session stops and the wallet is charged.
struct ChargingSessionReceipt: Equatable {
    let stationName: String
    let portLabel: String
    let energyKWh: Double
    let durationMinutes: Int
    let ratePerKWh: Double
    let sessionFee: Double
    let totalCharged: Double
    let isTestMode: Bool
}

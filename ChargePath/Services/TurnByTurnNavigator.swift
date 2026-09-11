//
//  TurnByTurnNavigator.swift
//  ChargePath
//
//  Protocol seam over an in-app turn-by-turn navigation engine. It keeps the
//  vendor SDK (Google Navigation) out of the ViewModel, which stays
//  framework-light and testable — `NavigationViewModel` talks only to this and
//  to the plain `NavWaypoint` / `NavUpdate` value types below.
//
//  The concrete `GoogleTurnByTurnNavigator` lives alongside; a test double
//  implements the same protocol.
//

import Foundation
import CoreLocation
import RxSwift

/// One stop on the guided route (origin, a charging stop, or the destination).
struct NavWaypoint: Equatable {
    let coordinate: CLLocationCoordinate2D
    let title: String

    static func == (lhs: NavWaypoint, rhs: NavWaypoint) -> Bool {
        lhs.title == rhs.title
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

/// A guidance tick the navigator pushes as the drive progresses.
struct NavUpdate: Equatable {
    /// Time to the final destination, seconds.
    let etaSeconds: TimeInterval
    /// Distance to the final destination, metres.
    let distanceMeters: CLLocationDistance
    /// Human instruction for the current maneuver, e.g. "Turn left onto Rue X".
    let maneuverText: String
}

enum TurnByTurnError: Error {
    /// No API key configured, or the SDK could not be initialised.
    case unavailable
    /// The engine could not build a route to the given waypoints.
    case noRoute
}

protocol TurnByTurnNavigator: AnyObject {
    /// true once the engine is usable (SDK initialised, API key present).
    var isAvailable: Bool { get }

    /// Guidance ticks — ETA, distance remaining, current maneuver text.
    var updates: Observable<NavUpdate> { get }

    /// Fires once when the driver reaches the final destination.
    var didArrive: Observable<Void> { get }

    /// Compute a route through `waypoints` in order (index 0 is the origin).
    func setDestinations(_ waypoints: [NavWaypoint]) -> Single<Void>

    /// Begin / end voice + on-screen guidance for the route from
    /// `setDestinations`.
    func startGuidance()
    func stopGuidance()
}

/// Stand-in used when the Google Navigation SDK isn't linked or has no API
/// key. `NavigationViewController` shows its "set GOOGLE_MAPS_API_KEY"
/// placeholder whenever `isAvailable` is false.
final class UnavailableTurnByTurnNavigator: TurnByTurnNavigator {
    let isAvailable = false
    var updates: Observable<NavUpdate> { .never() }
    var didArrive: Observable<Void> { .never() }
    func setDestinations(_ waypoints: [NavWaypoint]) -> Single<Void> {
        .error(TurnByTurnError.unavailable)
    }
    func startGuidance() {}
    func stopGuidance() {}
}

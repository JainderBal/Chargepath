//
//  LocationService.swift
//  ChargePath
//
//  Reactive location source for the Map screen (the user dot, the distance
//  sort, the "locate me" button).
//
//  The app ships with `FixedLocationService` wired in: it reports a fixed
//  Montréal position, needs no permission prompt, and guarantees the seeded
//  Montréal stations always fall inside the default search radius — so the
//  map is populated the moment anyone clones and runs the project, on a
//  simulator or a real device anywhere in the world.
//
//  `SystemLocationService` is the real `CLLocationManager` implementation,
//  kept here and drop-in swappable in `DependencyContainer`; it's just not
//  the default because a demo shouldn't hinge on the reviewer's location.
//

import Foundation
import CoreLocation
import RxSwift
import RxRelay

protocol LocationService: AnyObject {
    var authorizationStatus: Observable<CLAuthorizationStatus> { get }
    /// Latest fix. Emits after `requestLocation()` (and on significant change).
    var location: Observable<CLLocation> { get }

    func requestWhenInUseAuthorization()
    func requestLocation()
}

/// Reports a fixed Montréal location. No `CLLocationManager`, no permission
/// prompt — the seed data is Montréal-based, so this keeps the map populated
/// everywhere. Swap `SystemLocationService` in for real device location.
final class FixedLocationService: LocationService {

    /// Downtown Montréal — matches the map's initial region.
    static let montreal = CLLocation(latitude: 45.5230, longitude: -73.5870)

    private let locationRelay: BehaviorRelay<CLLocation>

    init(fixedLocation: CLLocation = FixedLocationService.montreal) {
        locationRelay = BehaviorRelay(value: fixedLocation)
    }

    var authorizationStatus: Observable<CLAuthorizationStatus> {
        .just(.authorizedWhenInUse)
    }
    var location: Observable<CLLocation> { locationRelay.asObservable() }

    func requestWhenInUseAuthorization() {}   // already "granted"
    func requestLocation() {
        locationRelay.accept(locationRelay.value)   // re-emit so "locate me" recentres
    }
}

final class SystemLocationService: NSObject, LocationService, CLLocationManagerDelegate {

    private let manager: CLLocationManager
    private let statusRelay: BehaviorRelay<CLAuthorizationStatus>
    private let locationRelay = PublishRelay<CLLocation>()

    var authorizationStatus: Observable<CLAuthorizationStatus> { statusRelay.asObservable() }
    var location: Observable<CLLocation> { locationRelay.asObservable() }

    override init() {
        manager = CLLocationManager()
        statusRelay = BehaviorRelay(value: manager.authorizationStatus)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break   // denied / restricted — nothing we can do from here
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        statusRelay.accept(manager.authorizationStatus)
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        locationRelay.accept(latest)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal: the map just stays where it is.
    }
}

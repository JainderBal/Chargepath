//
//  GoogleTurnByTurnNavigator.swift
//  ChargePath
//
//  Concrete `TurnByTurnNavigator` over the Google Navigation SDK for iOS.
//
//  The whole file is compiled only when the SDK is linked
//  (`#if canImport(GoogleNavigation)`), so the app still builds and every
//  other screen still works before the dependency is added in Xcode
//  (File ▸ Add Package Dependencies ▸ https://github.com/googlemaps/ios-navigation-sdk).
//  When the SDK is absent, `NavigationEngine.make()` returns an
//  `UnavailableTurnByTurnNavigator` and the screen shows its placeholder.
//

import UIKit
import RxSwift
import CoreLocation
import OSLog

private let navLog = Logger(subsystem: "com.chargepath.app", category: "Navigation")

/// One-call factory the Navigation screen uses to obtain its map view + a
/// navigator bound to it. Split out so the ViewController never imports the
/// vendor SDK directly.
enum NavigationEngine {

    /// `true` once `GMSServices.provideAPIKey` has run with a non-empty key.
    /// Set by `AppDelegate` at launch.
    static var isConfigured = false

    static func make() -> (mapView: UIView, navigator: TurnByTurnNavigator) {
        #if canImport(GoogleNavigation)
        if isConfigured, let pair = GoogleNavigationFactory.make() {
            return pair
        }
        #endif
        return (UIView(), UnavailableTurnByTurnNavigator())
    }

    /// Show Google's terms-of-service dialog once (the Navigation SDK refuses
    /// to start guidance until it's accepted), request location authorization
    /// (the SDK routes from the live GPS fix — with no fix, `setDestinations`
    /// fails), then continue. A no-op when the SDK isn't linked / configured.
    static func ensureConsent(then continuation: @escaping () -> Void) {
        #if canImport(GoogleNavigation)
        if isConfigured {
            LocationAuthorizationRequester.shared.request()
            GoogleNavigationConsent.ensure(then: continuation)
            return
        }
        #endif
        continuation()
    }
}

/// Fires the system location-permission prompt once (first launch) so the
/// Navigation SDK has a chance at a GPS fix. Kept as a singleton so the
/// `CLLocationManager` — and its delegate — isn't deallocated mid-request.
final class LocationAuthorizationRequester: NSObject, CLLocationManagerDelegate {
    static let shared = LocationAuthorizationRequester()
    private let manager = CLLocationManager()

    override private init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }
}

#if canImport(GoogleNavigation)
import GoogleNavigation
import GoogleMaps
import RxRelay

enum GoogleNavigationConsent {
    static func ensure(then continuation: @escaping () -> Void) {
        if GMSNavigationServices.areTermsAndConditionsAccepted() {
            continuation()
            return
        }
        GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(
            withCompanyName: "ChargePath"
        ) { _ in continuation() }
    }
}

enum GoogleNavigationFactory {
    static func make() -> (mapView: UIView, navigator: TurnByTurnNavigator)? {
        let mapView = GMSMapView(frame: .zero)
        mapView.isNavigationEnabled = true
        // Explicitly kick-starts this map view's own location updates — each
        // fresh GMSMapView otherwise takes a beat to acquire a fix, which is
        // what the retry loop below in `GoogleTurnByTurnNavigator` covers.
        mapView.isMyLocationEnabled = true
        mapView.settings.compassButton = true
        mapView.cameraMode = .following
        guard mapView.navigator != nil else { return nil }
        return (mapView, GoogleTurnByTurnNavigator(mapView: mapView))
    }
}

final class GoogleTurnByTurnNavigator: NSObject, TurnByTurnNavigator {

    private let mapView: GMSMapView
    private let updatesRelay = PublishRelay<NavUpdate>()
    private let arriveRelay = PublishRelay<Void>()

    private var remainingTime: TimeInterval = 0
    private var remainingDistance: CLLocationDistance = 0

    init(mapView: GMSMapView) {
        self.mapView = mapView
        super.init()
        mapView.navigator?.add(self)
        mapView.navigator?.timeUpdateThreshold = 5
        mapView.navigator?.distanceUpdateThreshold = 50
    }

    var isAvailable: Bool { mapView.navigator != nil }
    var updates: Observable<NavUpdate> { updatesRelay.asObservable() }
    var didArrive: Observable<Void> { arriveRelay.asObservable() }

    /// Retries this many times when the SDK reports `.locationUnavailable` —
    /// on a freshly-opened screen the app can be a step ahead of the SDK's
    /// own location provider getting its first GPS fix, even once permission
    /// is granted. A short backoff nearly always clears it; anything else
    /// fails immediately.
    private static let locationRetryDelays: [TimeInterval] = [1, 2, 3, 4, 5]

    func setDestinations(_ waypoints: [NavWaypoint]) -> Single<Void> {
        Single.create { [mapView] observer in
            guard let navigator = mapView.navigator else {
                navLog.error("setDestinations: mapView.navigator is nil (SDK not enabled)")
                observer(.failure(TurnByTurnError.unavailable))
                return Disposables.create()
            }
            let gms = waypoints.compactMap {
                GMSNavigationWaypoint(location: $0.coordinate, title: $0.title)
            }
            guard !gms.isEmpty else {
                navLog.error("setDestinations: no valid GMSNavigationWaypoint from \(waypoints.count) input(s)")
                observer(.failure(TurnByTurnError.routeFailed(reason: "invalidWaypoint")))
                return Disposables.create()
            }
            var cancelled = false
            Self.attempt(navigator: navigator, waypoints: gms, remainingDelays: Self.locationRetryDelays) { result in
                guard !cancelled else { return }
                switch result {
                case .success: observer(.success(()))
                case .failure(let error): observer(.failure(error))
                }
            }
            return Disposables.create { cancelled = true }
        }
    }

    private static func attempt(navigator: GMSNavigator,
                                waypoints: [GMSNavigationWaypoint],
                                remainingDelays: [TimeInterval],
                                completion: @escaping (Result<Void, Error>) -> Void) {
        navLog.info("setDestinations: \(waypoints.count) waypoint(s), location auth = \(CLLocationManager().authorizationStatus.rawValue)")
        navigator.setDestinations(waypoints) { routeStatus in
            if routeStatus == .OK {
                completion(.success(()))
                return
            }
            let reason = String(describing: routeStatus)
            if routeStatus == .locationUnavailable, let delay = remainingDelays.first {
                navLog.info("setDestinations: locationUnavailable, retrying in \(delay, privacy: .public)s (\(remainingDelays.count) attempt(s) left)")
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    attempt(navigator: navigator, waypoints: waypoints,
                           remainingDelays: Array(remainingDelays.dropFirst()), completion: completion)
                }
                return
            }
            navLog.error("setDestinations failed: \(reason, privacy: .public)")
            completion(.failure(TurnByTurnError.routeFailed(reason: reason)))
        }
    }

    func startGuidance() {
        mapView.navigator?.isGuidanceActive = true
        mapView.locationSimulator?.stopSimulation()
        mapView.cameraMode = .following
    }

    func stopGuidance() {
        mapView.navigator?.isGuidanceActive = false
        mapView.navigator?.clearDestinations()
    }
}

extension GoogleTurnByTurnNavigator: GMSNavigatorListener {

    func navigator(_ navigator: GMSNavigator, didUpdateRemainingTime time: TimeInterval) {
        remainingTime = time
        emit()
    }

    func navigator(_ navigator: GMSNavigator, didUpdateRemainingDistance distance: CLLocationDistance) {
        remainingDistance = distance
        emit()
    }

    func navigator(_ navigator: GMSNavigator, didArriveAt waypoint: GMSNavigationWaypoint) {
        arriveRelay.accept(())
    }

    private func emit() {
        updatesRelay.accept(NavUpdate(
            etaSeconds: remainingTime,
            distanceMeters: remainingDistance,
            maneuverText: ""      // the SDK's built-in header renders the maneuver
        ))
    }
}
#endif

//
//  NavigationViewModelTests.swift
//  ChargePathTests
//

import XCTest
import CoreLocation
import RxSwift
@testable import ChargePath

@MainActor
final class NavigationViewModelTests: XCTestCase {

    private var bag = DisposeBag()

    override func setUp() {
        super.setUp()
        bag = DisposeBag()
    }

    private func pump(_ seconds: TimeInterval = 0.05) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func plan(stops: Int) -> RoutePlan {
        let stopModels = (0..<stops).map { i in
            ChargingStop(
                index: i + 1,
                station: Fixture.station(id: "s\(i)", name: "Stop \(i)", lat: 45.5 + Double(i), lon: -73.6),
                distanceIntoTripKm: Double((i + 1) * 100),
                arrivalStateOfChargePercent: 30,
                estimatedChargeMinutes: 20
            )
        }
        return RoutePlan(
            origin: CLLocationCoordinate2D(latitude: 45.5, longitude: -73.6),
            destination: CLLocationCoordinate2D(latitude: 48.0, longitude: -71.0),
            routeCoordinates: [], totalDistanceKm: 300, stops: stopModels,
            driveTimeSeconds: 3 * 3600
        )
    }

    func test_start_sends_waypoints_in_order_and_starts_guidance() {
        let waypoints = NavigationViewModel.waypoints(for: plan(stops: 2), destinationTitle: "Québec")
        let nav = TurnByTurnNavigatorDouble()
        let vm = NavigationViewModel(waypoints: waypoints, localizationRepository: LocalizationRepositoryDouble())

        vm.bind(navigator: nav)
        pump()

        XCTAssertEqual(nav.receivedWaypoints.map(\.title), ["Stop 0", "Stop 1", "Québec"])
        XCTAssertEqual(nav.startGuidanceCount, 1)
        XCTAssertTrue(vm.isNavigating.value)
        XCTAssertNil(vm.unavailableText.value)
        XCTAssertEqual(vm.destinationName.value, "Québec")
    }

    func test_single_station_yields_one_waypoint() {
        let station = Fixture.station(id: "x", name: "Marché Atwater")
        let waypoints = NavigationViewModel.waypoints(for: station)
        XCTAssertEqual(waypoints.map(\.title), ["Marché Atwater"])
    }

    func test_nav_updates_flow_to_outputs() {
        let nav = TurnByTurnNavigatorDouble()
        let vm = NavigationViewModel(
            waypoints: NavigationViewModel.waypoints(for: plan(stops: 1), destinationTitle: "End"),
            localizationRepository: LocalizationRepositoryDouble()
        )
        vm.bind(navigator: nav)
        pump()

        nav.updatesRelay.accept(NavUpdate(etaSeconds: 3720, distanceMeters: 2500, maneuverText: ""))
        pump()

        XCTAssertEqual(vm.etaText.value, "1 h 2 min")
        XCTAssertEqual(vm.distanceText.value, "2.5 km")
    }

    func test_arrival_stops_navigation_and_reports() {
        let nav = TurnByTurnNavigatorDouble()
        let vm = NavigationViewModel(
            waypoints: NavigationViewModel.waypoints(for: plan(stops: 1), destinationTitle: "End"),
            localizationRepository: LocalizationRepositoryDouble()
        )
        var arrived = false
        vm.arrived.subscribe(onNext: { arrived = true }).disposed(by: bag)
        vm.bind(navigator: nav)
        pump()

        nav.arriveRelay.accept(())
        pump()

        XCTAssertFalse(vm.isNavigating.value)
        XCTAssertTrue(arrived)
        XCTAssertEqual(vm.maneuverText.value, "You’ve arrived")
    }

    func test_stop_ends_guidance_and_exits() {
        let nav = TurnByTurnNavigatorDouble()
        let vm = NavigationViewModel(
            waypoints: NavigationViewModel.waypoints(for: plan(stops: 1), destinationTitle: "End"),
            localizationRepository: LocalizationRepositoryDouble()
        )
        var exited = false
        vm.onExit = { exited = true }
        vm.bind(navigator: nav)
        pump()

        vm.stop()

        XCTAssertEqual(nav.stopGuidanceCount, 1)
        XCTAssertFalse(vm.isNavigating.value)
        XCTAssertTrue(exited)
    }

    func test_unavailable_navigator_shows_placeholder_text() {
        let nav = TurnByTurnNavigatorDouble()
        nav.available = false
        let vm = NavigationViewModel(
            waypoints: NavigationViewModel.waypoints(for: plan(stops: 1), destinationTitle: "End"),
            localizationRepository: LocalizationRepositoryDouble()
        )
        vm.bind(navigator: nav)
        pump()

        XCTAssertNotNil(vm.unavailableText.value)
        XCTAssertEqual(nav.startGuidanceCount, 0)
        XCTAssertFalse(vm.isNavigating.value)
    }
}

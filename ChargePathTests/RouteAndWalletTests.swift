//
//  RouteAndWalletTests.swift
//  ChargePathTests
//

import XCTest
import CoreLocation
import RxSwift
@testable import ChargePath

/// Subscribe to a Single and block the test until it resolves.
func awaitValue<T>(_ single: Single<T>, timeout: TimeInterval = 5,
                           file: StaticString = #file, line: UInt = #line) throws -> T {
    let exp = XCTestExpectation(description: "Single")
    var result: Result<T, Error>?
    let d = single.subscribe(onSuccess: { result = .success($0); exp.fulfill() },
                             onFailure: { result = .failure($0); exp.fulfill() })
    defer { d.dispose() }
    _ = XCTWaiter().wait(for: [exp], timeout: timeout)
    switch try XCTUnwrap(result, "Single did not resolve in time", file: file, line: line) {
    case .success(let v): return v
    case .failure(let e): throw e
    }
}

final class WalletTests: XCTestCase {

    func test_transaction_amount_text() {
        XCTAssertEqual(
            WalletTransaction(title: "t", subtitle: "s", amount: 25, kind: .credit).amountText,
            "+$25.00")
        XCTAssertEqual(
            WalletTransaction(title: "t", subtitle: "s", amount: -12.16, kind: .debit).amountText,
            "-$12.16")
    }

    func test_addFunds_increases_balance_and_prepends_history() {
        let store = InMemoryKeyValueStore()
        let repo = DefaultWalletRepository(store: store)
        let before = repo.currentWallet.balance

        repo.addFunds(25)

        XCTAssertEqual(repo.currentWallet.balance, before + 25, accuracy: 0.001)
        XCTAssertEqual(repo.currentWallet.transactions.first?.kind, .credit)
        XCTAssertEqual(repo.currentWallet.transactions.first?.amount, 25)
    }

    func test_addFunds_ignores_non_positive() {
        let repo = DefaultWalletRepository(store: InMemoryKeyValueStore())
        let before = repo.currentWallet
        repo.addFunds(0)
        repo.addFunds(-5)
        XCTAssertEqual(repo.currentWallet, before)
    }
}

@MainActor
final class RouteRepositoryTests: XCTestCase {

    func test_falls_back_to_estimate_when_geocoding_fails() throws {
        let geocoder = GeocodingServiceDouble()          // errors by default
        let repo = DefaultRouteRepository(
            geocoder: geocoder,
            directions: RouteDirectionsServiceDouble(),
            stationRepository: StationRepositoryDouble(StationSeed.stations)
        )
        let query = TripQuery(originText: "A", destinationText: "B",
                              vehicleRangeKm: 400, vehicleConnector: .ccs)

        let plan = try awaitValue(repo.planTrip(query))

        XCTAssertTrue(plan.isEstimate)
        XCTAssertFalse(plan.stops.isEmpty)               // demo plan has stops
        XCTAssertGreaterThan(plan.routeCoordinates.count, 1)
    }

    func test_builds_real_plan_with_stops_for_a_long_trip() throws {
        let geocoder = GeocodingServiceDouble()
        geocoder.result = .just(CLLocationCoordinate2D(latitude: 45.5, longitude: -73.6))
        let directions = RouteDirectionsServiceDouble()
        // ~600 km straight line — a 400 km car must stop at least once.
        directions.result = .just(DirectionsResult(
            polyline: [
                CLLocationCoordinate2D(latitude: 45.5, longitude: -73.6),
                CLLocationCoordinate2D(latitude: 48.0, longitude: -71.0),
                CLLocationCoordinate2D(latitude: 50.9, longitude: -68.0)
            ],
            distanceMeters: 600_000,
            expectedTravelTimeSeconds: 6 * 3600))
        let repo = DefaultRouteRepository(
            geocoder: geocoder, directions: directions,
            stationRepository: StationRepositoryDouble(StationSeed.stations))

        let plan = try awaitValue(repo.planTrip(TripQuery(
            originText: "A", destinationText: "B",
            vehicleRangeKm: 400, vehicleConnector: .ccs)))

        XCTAssertFalse(plan.isEstimate)
        XCTAssertGreaterThanOrEqual(plan.stops.count, 1)
        XCTAssertEqual(plan.totalDistanceKm, 600, accuracy: 1)
        XCTAssertEqual(plan.driveTimeSeconds, 6 * 3600, accuracy: 1)
        XCTAssertEqual(plan.driveTimeText, "6 h 0 min")
        // arrival SoC never planned below the 15% reserve
        for stop in plan.stops {
            XCTAssertGreaterThanOrEqual(stop.arrivalStateOfChargePercent, 15)
        }
    }
}

// Minimal KeyValueStore for tests.
final class InMemoryKeyValueStore: KeyValueStore {
    private var data: [String: Data] = [:]
    private var bools: [String: Bool] = [:]
    func data(forKey key: String) -> Data? { data[key] }
    func set(_ data: Data?, forKey key: String) { self.data[key] = data }
    func bool(forKey key: String) -> Bool { bools[key] ?? false }
    func set(_ value: Bool, forKey key: String) { bools[key] = value }
}

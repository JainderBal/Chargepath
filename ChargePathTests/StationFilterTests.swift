//
//  StationFilterTests.swift
//  ChargePathTests
//

import XCTest
@testable import ChargePath

final class StationFilterTests: XCTestCase {

    private func station(connectors: [Connector] = [.ccs],
                         ports: [ChargingPort]) -> Station {
        Fixture.station(id: "s", connectors: connectors, ports: ports)
    }

    private func port(_ connector: Connector, _ kw: Int, _ status: PortStatus) -> ChargingPort {
        ChargingPort(id: UUID().uuidString, label: "P", connector: connector,
                     powerKW: kw, status: status, note: nil)
    }

    func test_default_filter_matches_a_nearby_station() {
        let s = station(ports: [port(.ccs, 50, .inUse)])
        // Unknown distance (nil) is not filtered; a station within the default
        // 25 km radius passes; one outside it does not.
        XCTAssertTrue(StationFilter.default.matches(
            s, vehicleConnector: .nacs, isBookmarked: false, distanceKm: nil))
        XCTAssertTrue(StationFilter.default.matches(
            s, vehicleConnector: .nacs, isBookmarked: false, distanceKm: 12))
        XCTAssertFalse(StationFilter.default.matches(
            s, vehicleConnector: .nacs, isBookmarked: false, distanceKm: 999))
    }

    func test_bookmarked_segment_excludes_unbookmarked() {
        var f = StationFilter.default
        f.segment = .bookmarked
        let s = station(ports: [port(.ccs, 50, .available)])
        XCTAssertFalse(f.matches(s, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
        XCTAssertTrue(f.matches(s, vehicleConnector: nil, isBookmarked: true, distanceKm: nil))
    }

    func test_connector_filter_bites_only_when_one_is_disabled() {
        var f = StationFilter.default
        let nacsOnly = station(connectors: [.nacs], ports: [port(.nacs, 250, .available)])
        XCTAssertTrue(f.matches(nacsOnly, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
        f.connectors = [.ccs, .j1772]                       // NACS disabled
        XCTAssertFalse(f.matches(nacsOnly, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
    }

    func test_availability_two_ports_free() {
        var f = StationFilter.default
        f.availability = .twoFree
        let oneFree = station(ports: [port(.ccs, 50, .available), port(.ccs, 50, .inUse)])
        let twoFree = station(ports: [port(.ccs, 50, .available), port(.ccs, 50, .available)])
        XCTAssertFalse(f.matches(oneFree, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
        XCTAssertTrue(f.matches(twoFree, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
    }

    func test_power_ultra_requires_250kW() {
        var f = StationFilter.default
        f.power = .ultra
        let fast = station(ports: [port(.ccs, 150, .available)])
        let ultra = station(ports: [port(.ccs, 350, .available)])
        XCTAssertFalse(f.matches(fast, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
        XCTAssertTrue(f.matches(ultra, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
    }

    func test_radius_excludes_far_stations() {
        var f = StationFilter.default
        f.radiusKm = 10
        let s = station(ports: [port(.ccs, 50, .available)])
        XCTAssertTrue(f.matches(s, vehicleConnector: nil, isBookmarked: false, distanceKm: 8))
        XCTAssertFalse(f.matches(s, vehicleConnector: nil, isBookmarked: false, distanceKm: 42))
    }

    func test_compatibleOnly_needs_matching_connector() {
        var f = StationFilter.default
        f.compatibleOnly = true
        let ccs = station(connectors: [.ccs], ports: [port(.ccs, 50, .available)])
        XCTAssertFalse(f.matches(ccs, vehicleConnector: .nacs, isBookmarked: false, distanceKm: nil))
        XCTAssertTrue(f.matches(ccs, vehicleConnector: .ccs, isBookmarked: false, distanceKm: nil))
    }

    func test_query_matches_name_or_address() {
        var f = StationFilter.default
        f.query = "sauvé"
        let hit = Fixture.station(id: "s", name: "Marché Central")
        var hit2 = hit; _ = hit2
        let named = Station(id: "s", name: "Marché Central", address: "1500 Rue Sauvé O",
                            coordinate: hit.coordinate, connectors: [.ccs],
                            priceText: nil, ports: hit.ports)
        XCTAssertTrue(f.matches(named, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
        f.query = "nope"
        XCTAssertFalse(f.matches(named, vehicleConnector: nil, isBookmarked: false, distanceKm: nil))
    }

    func test_activeAdjustmentCount() {
        var f = StationFilter.default
        XCTAssertEqual(f.activeAdjustmentCount, 0)
        f.power = .fast
        f.compatibleOnly = true
        XCTAssertEqual(f.activeAdjustmentCount, 2)
    }
}

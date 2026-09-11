//
//  ConnectorAndDTOTests.swift
//  ChargePathTests
//

import XCTest
@testable import ChargePath

final class ConnectorTests: XCTestCase {

    func test_apiValue_parsing() {
        XCTAssertEqual(Connector(apiValue: "CCS"), .ccs)
        XCTAssertEqual(Connector(apiValue: "SAE Combo"), .ccs)
        XCTAssertEqual(Connector(apiValue: "J1772 Combo"), .ccs)     // Combo → CCS, not J1772
        XCTAssertEqual(Connector(apiValue: "J1772"), .j1772)
        XCTAssertEqual(Connector(apiValue: "Tesla"), .nacs)
        XCTAssertEqual(Connector(apiValue: "NACS"), .nacs)
        XCTAssertEqual(Connector(apiValue: "CHAdeMO"), .unknown)
        XCTAssertEqual(Connector(apiValue: ""), .unknown)
    }

    func test_portStatus_from_status_code() {
        XCTAssertEqual(PortStatus(rawValue: 1), .available)
        XCTAssertEqual(PortStatus(rawValue: 2), .inUse)
        XCTAssertEqual(PortStatus(rawValue: 3), .offline)
        XCTAssertEqual(PortStatus(rawValue: 99), nil)
    }
}

final class ChargeHubDTOTests: XCTestCase {

    /// The exact ChargeHub /demo/locations shape (nested Connectors array).
    private let locationsJSON = """
    [{
      "LocID": 42, "LocName": "Depot", "StreetAddress": "9 Rue X",
      "Latitude": 45.51, "Longitude": -73.57,
      "Ports": [
        { "PortID": 100, "Level": 3, "DisplayName": "A1", "KW": 180,
          "Connectors": [["Tesla"]], "ChargingCostDisplay": "$0.40 / kWh" },
        { "PortID": 101, "Level": 2, "DisplayName": "A2", "KW": 7,
          "Connectors": [["J1772"]], "ChargingCostDisplay": "$0.40 / kWh" }
      ]
    }]
    """.data(using: .utf8)!

    func test_decodes_locations_array_into_domain() throws {
        let dtos = try JSONDecoder().decode([ChargeHubStationDTO].self, from: locationsJSON)
        let stations = dtos.compactMap { $0.toDomain() }
        XCTAssertEqual(stations.count, 1)

        let s = try XCTUnwrap(stations.first)
        XCTAssertEqual(s.id, "42")
        XCTAssertEqual(s.name, "Depot")
        XCTAssertEqual(s.coordinate.latitude, 45.51, accuracy: 0.0001)
        XCTAssertEqual(s.priceText, "$0.40 / kWh")
        XCTAssertEqual(s.ports.count, 2)
        XCTAssertEqual(s.ports[0].connector, .nacs)     // "Tesla" flattened + mapped
        XCTAssertEqual(s.ports[0].powerKW, 180)
        XCTAssertEqual(s.ports[0].label, "A1")
        XCTAssertEqual(s.ports[1].connector, .j1772)
        XCTAssertEqual(Set(s.connectors), Set([.nacs, .j1772]))
        XCTAssertEqual(s.ports[0].status, .unknown)     // Locations payload carries no status
    }

    func test_drops_rows_without_coordinates() throws {
        let json = #"[{"LocID": 1, "LocName": "No coords"}]"#.data(using: .utf8)!
        let dtos = try JSONDecoder().decode([ChargeHubStationDTO].self, from: json)
        XCTAssertTrue(dtos.compactMap { $0.toDomain() }.isEmpty)
    }

    func test_status_response_maps_by_portID() throws {
        let json = """
        [{ "LocID": 42, "PortID": 100, "StatusCode": 2, "StatusTime": "x" },
         { "LocID": 42, "PortID": 101, "StatusCode": 3, "StatusTime": "x" }]
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(ChargeHubStatusResponse.self, from: json)
        XCTAssertEqual(resp.statusByPortID["100"], .inUse)
        XCTAssertEqual(resp.statusByPortID["101"], .offline)
    }

    func test_bundled_seed_json_decodes_and_merges_status() throws {
        // StationSeed.stations is loaded from the bundled ChargeHub-shaped JSON
        // through the same DTO pipeline.
        let seeds = StationSeed.stations
        XCTAssertGreaterThanOrEqual(seeds.count, 5)
        let marche = try XCTUnwrap(seeds.first { $0.name == "Marché Central" })
        // status sample sets A1 available, A2 in use, A4 offline
        XCTAssertEqual(marche.ports.first { $0.label == "A1" }?.status, .available)
        XCTAssertEqual(marche.ports.first { $0.label == "A2" }?.status, .inUse)
        XCTAssertEqual(marche.ports.first { $0.label == "A4" }?.status, .offline)
    }
}

//
//  OpenChargeMapDTOTests.swift
//  ChargePathTests
//

import XCTest
@testable import ChargePath

final class OpenChargeMapDTOTests: XCTestCase {

    /// A trimmed `/v3/poi?verbose=false` response: two POIs, one of them
    /// missing coordinates.
    private let poiJSON = """
    [
      {
        "ID": 90210,
        "UsageCost": "$0.31/kWh",
        "StatusType": { "IsOperational": true },
        "OperatorInfo": { "Title": "Circuit Électrique" },
        "AddressInfo": {
          "Title": "Marché Atwater",
          "AddressLine1": "138 Av Atwater",
          "Town": "Montréal",
          "StateOrProvince": "QC",
          "Latitude": 45.4795,
          "Longitude": -73.5793
        },
        "Connections": [
          {
            "ConnectionType": { "Title": "CCS (Type 1)" },
            "Level": { "Title": "Level 3 : High (Over 40kW)" },
            "PowerKW": 100.0,
            "Quantity": 2,
            "StatusType": { "IsOperational": true }
          },
          {
            "ConnectionType": { "Title": "CHAdeMO" },
            "PowerKW": 50.0,
            "StatusType": { "IsOperational": false }
          }
        ]
      },
      {
        "ID": 5,
        "AddressInfo": { "Title": "No coordinates" }
      }
    ]
    """.data(using: .utf8)!

    func test_decodes_poi_array_into_domain() throws {
        let dtos = try JSONDecoder().decode([OCMPoiDTO].self, from: poiJSON)
        let stations = dtos.compactMap { $0.toDomain() }

        XCTAssertEqual(stations.count, 1, "the row without coordinates is dropped")

        let s = try XCTUnwrap(stations.first)
        XCTAssertEqual(s.id, "90210")
        XCTAssertEqual(s.name, "Marché Atwater")
        XCTAssertEqual(s.address, "138 Av Atwater, Montréal, QC")
        XCTAssertEqual(s.coordinate.latitude, 45.4795, accuracy: 0.0001)
        XCTAssertEqual(s.priceText, "$0.31/kWh")
        XCTAssertEqual(s.ports.count, 2)

        let ccs = try XCTUnwrap(s.ports.first { $0.connector == .ccs })
        XCTAssertEqual(ccs.powerKW, 100)
        XCTAssertEqual(ccs.label, "CCS ×2")
        XCTAssertEqual(ccs.status, .available)

        let chademo = try XCTUnwrap(s.ports.first { $0.connector == .unknown })
        XCTAssertEqual(chademo.powerKW, 50)
        XCTAssertEqual(chademo.status, .offline, "IsOperational:false → offline")
        XCTAssertEqual(chademo.label, "CHAdeMO")

        XCTAssertEqual(Set(s.connectors), Set([.ccs, .unknown]))
    }

    func test_missing_operational_flag_reads_as_unknown() throws {
        let json = """
        [{
          "ID": 1,
          "AddressInfo": { "Latitude": 1.0, "Longitude": 2.0 },
          "Connections": [ { "ConnectionType": { "Title": "J1772" }, "PowerKW": 7 } ]
        }]
        """.data(using: .utf8)!
        let station = try XCTUnwrap(
            try JSONDecoder().decode([OCMPoiDTO].self, from: json).first?.toDomain()
        )
        XCTAssertEqual(station.ports.first?.connector, .j1772)
        XCTAssertEqual(station.ports.first?.status, .unknown)
    }
}

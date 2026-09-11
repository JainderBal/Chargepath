//
//  GoogleDirectionsTests.swift
//  ChargePathTests
//

import XCTest
@testable import ChargePath

final class GooglePolylineDecoderTests: XCTestCase {

    func test_decodes_the_canonical_google_example() {
        // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
        let coords = GooglePolylineDecoder.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(coords.count, 3)
        XCTAssertEqual(coords[0].latitude, 38.5, accuracy: 1e-5)
        XCTAssertEqual(coords[0].longitude, -120.2, accuracy: 1e-5)
        XCTAssertEqual(coords[1].latitude, 40.7, accuracy: 1e-5)
        XCTAssertEqual(coords[1].longitude, -120.95, accuracy: 1e-5)
        XCTAssertEqual(coords[2].latitude, 43.252, accuracy: 1e-5)
        XCTAssertEqual(coords[2].longitude, -126.453, accuracy: 1e-5)
    }

    func test_empty_string_decodes_to_no_points() {
        XCTAssertTrue(GooglePolylineDecoder.decode("").isEmpty)
    }
}

final class GoogleDirectionsResponseTests: XCTestCase {

    func test_prefers_duration_in_traffic_when_present() throws {
        let json = """
        {
          "status": "OK",
          "routes": [{
            "overview_polyline": { "points": "_p~iF~ps|U_ulLnnqC" },
            "legs": [{
              "distance": { "value": 12345 },
              "duration": { "value": 600 },
              "duration_in_traffic": { "value": 900 }
            }]
          }]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(GoogleDirectionsResponse.self, from: json)
        let result = try XCTUnwrap(response.toDirectionsResult())
        XCTAssertEqual(result.distanceMeters, 12345)
        XCTAssertEqual(result.expectedTravelTimeSeconds, 900)
        XCTAssertEqual(result.polyline.count, 2)
    }

    func test_falls_back_to_plain_duration_without_traffic() throws {
        let json = """
        {
          "status": "OK",
          "routes": [{
            "overview_polyline": { "points": "_p~iF~ps|U_ulLnnqC" },
            "legs": [{ "distance": { "value": 1000 }, "duration": { "value": 120 } }]
          }]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(GoogleDirectionsResponse.self, from: json)
        let result = try XCTUnwrap(response.toDirectionsResult())
        XCTAssertEqual(result.expectedTravelTimeSeconds, 120)
    }

    func test_no_routes_yields_nil() throws {
        let json = #"{ "status": "ZERO_RESULTS", "routes": [] }"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(GoogleDirectionsResponse.self, from: json)
        XCTAssertNil(response.toDirectionsResult())
    }
}

final class GoogleGeocodeResponseTests: XCTestCase {

    func test_first_result_coordinate() throws {
        let json = """
        {
          "status": "OK",
          "results": [{ "geometry": { "location": { "lat": 45.5, "lng": -73.6 } } }]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(GoogleGeocodeResponse.self, from: json)
        let coordinate = try XCTUnwrap(response.firstCoordinate)
        XCTAssertEqual(coordinate.latitude, 45.5, accuracy: 1e-9)
        XCTAssertEqual(coordinate.longitude, -73.6, accuracy: 1e-9)
    }

    func test_no_results_yields_nil() throws {
        let json = #"{ "status": "ZERO_RESULTS", "results": [] }"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(GoogleGeocodeResponse.self, from: json)
        XCTAssertNil(response.firstCoordinate)
    }
}

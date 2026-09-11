//
//  GooglePolylineDecoder.swift
//  ChargePath
//
//  Decodes Google's "encoded polyline" format (the `overview_polyline.points`
//  field on a Directions API route) into coordinates. Standard algorithm:
//  https://developers.google.com/maps/documentation/utilities/polylinealgorithm
//

import Foundation
import CoreLocation

enum GooglePolylineDecoder {

    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        let chars = Array(encoded.utf8)
        var index = 0
        var lat = 0
        var lng = 0

        while index < chars.count {
            guard let deltaLat = decodeValue(chars, &index) else { break }
            lat += deltaLat
            guard let deltaLng = decodeValue(chars, &index) else { break }
            lng += deltaLng

            coordinates.append(CLLocationCoordinate2D(
                latitude: Double(lat) * 1e-5,
                longitude: Double(lng) * 1e-5
            ))
        }
        return coordinates
    }

    /// Decodes one variable-length, zigzag-encoded value starting at `index`,
    /// advancing it past the value. `nil` if the buffer ends mid-value.
    private static func decodeValue(_ chars: [UInt8], _ index: inout Int) -> Int? {
        var result = 0
        var shift = 0
        var byte: Int
        repeat {
            guard index < chars.count else { return nil }
            byte = Int(chars[index]) - 63
            index += 1
            result |= (byte & 0x1f) << shift
            shift += 5
        } while byte >= 0x20
        return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }
}

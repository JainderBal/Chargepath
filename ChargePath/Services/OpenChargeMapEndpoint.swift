//
//  OpenChargeMapEndpoint.swift
//  ChargePath
//
//  The Open Charge Map REST calls the app makes, as `URLRequestConvertible`.
//
//  Open Charge Map (https://openchargemap.org) is a community-run, openly
//  licensed EV charging registry with global coverage. Unlike the ChargeHub
//  demo tier it answers real bounding-box queries, so it backs the live map.
//
//    • POI:  GET https://api.openchargemap.io/v3/poi
//            auth: `key` query param (or X-API-Key header); keyless traffic is
//            allowed but heavily rate-limited
//            geo:  boundingbox=(minLat,minLon),(maxLat,maxLon)
//

import Foundation
import Alamofire
import MapKit

enum OpenChargeMapEndpoint: URLRequestConvertible {

    case poi(region: MKCoordinateRegion, apiKey: String, maxResults: Int)

    private var path: String {
        switch self {
        case .poi: return "poi"
        }
    }

    private var queryItems: [URLQueryItem] {
        switch self {
        case let .poi(region, apiKey, maxResults):
            let minLat = region.center.latitude - region.span.latitudeDelta / 2
            let maxLat = region.center.latitude + region.span.latitudeDelta / 2
            let minLon = region.center.longitude - region.span.longitudeDelta / 2
            let maxLon = region.center.longitude + region.span.longitudeDelta / 2
            var items = [
                URLQueryItem(name: "output", value: "json"),
                URLQueryItem(name: "compact", value: "true"),
                URLQueryItem(name: "verbose", value: "false"),
                URLQueryItem(name: "maxresults", value: String(maxResults)),
                URLQueryItem(
                    name: "boundingbox",
                    value: "(\(minLat),\(minLon)),(\(maxLat),\(maxLon))"
                )
            ]
            if !apiKey.isEmpty {
                items.append(URLQueryItem(name: "key", value: apiKey))
            }
            return items
        }
    }

    private var apiKey: String {
        switch self {
        case let .poi(_, key, _): return key
        }
    }

    func asURLRequest() throws -> URLRequest {
        let base = APIConfig.default.openChargeMapBaseURL
        var components = URLComponents(
            url: base.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        return request
    }
}

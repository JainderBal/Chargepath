//
//  ChargeHubEndpoint.swift
//  ChargePath
//
//  The ChargeHub REST calls the app makes, as `URLRequestConvertible`.
//
//  Verified against the "Demo - POI" API on developer.chargehub.com:
//    • Locations:  GET https://apiv3.chargehub.com/demo/locations
//                  auth: Ocp-Apim-Subscription-Key header
//                  the demo dataset ignores geo params (a paid tier takes a
//                  bounding box here)
//    • Status:     GET https://apiv3.chargehub.com/demo/status?locId={id}
//                  (path is a best guess — grab the Status operation spec from
//                  the portal to confirm)
//

import Foundation
import Alamofire
import MapKit

enum ChargeHubEndpoint: URLRequestConvertible {

    case locations(region: MKCoordinateRegion, apiKey: String, limit: Int)
    case status(locationID: String, apiKey: String)

    private var apiKey: String {
        switch self {
        case let .locations(_, key, _): return key
        case let .status(_, key): return key
        }
    }

    private var path: String {
        switch self {
        case .locations: return "locations"
        case .status:    return "status"
        }
    }

    private var queryItems: [URLQueryItem] {
        switch self {
        case .locations:
            // Demo dataset returns a fixed sample regardless of bounds. A paid
            // ("Trial - POI") tier accepts lat/lon bounding-box params here.
            return []
        case let .status(locationID, _):
            return [URLQueryItem(name: "locId", value: locationID)]
        }
    }

    func asURLRequest() throws -> URLRequest {
        let base = APIConfig.default.chargeHubBaseURL
        var components = URLComponents(
            url: base.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        let items = queryItems
        components.queryItems = items.isEmpty ? nil : items

        var request = URLRequest(url: components.url!)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        return request
    }
}

//
//  GeocodingService.swift
//  ChargePath
//
//  Turns the free-text "Start" / "Destination" fields on the Route Planner
//  into coordinates. Wraps CLGeocoder behind a protocol for testability.
//

import Foundation
import CoreLocation
import RxSwift

protocol GeocodingService: AnyObject {
    func coordinate(for query: String) -> Single<CLLocationCoordinate2D>
}

enum GeocodingError: Error { case notFound }

final class AppleGeocodingService: GeocodingService {

    private let geocoder = CLGeocoder()

    func coordinate(for query: String) -> Single<CLLocationCoordinate2D> {
        Single.create { [geocoder] observer in
            geocoder.geocodeAddressString(query) { placemarks, _ in
                if let location = placemarks?.first?.location {
                    observer(.success(location.coordinate))
                } else {
                    observer(.failure(GeocodingError.notFound))
                }
            }
            return Disposables.create { geocoder.cancelGeocode() }
        }
    }
}

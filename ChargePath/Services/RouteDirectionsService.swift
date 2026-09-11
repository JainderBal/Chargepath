//
//  RouteDirectionsService.swift
//  ChargePath
//
//  Wraps MKDirections to get a real driving polyline + distance between two
//  coordinates. The Route *Repository* uses this plus the station data to
//  place charging stops.
//

import Foundation
import MapKit
import RxSwift

struct DirectionsResult {
    let polyline: [CLLocationCoordinate2D]
    let distanceMeters: CLLocationDistance
}

protocol RouteDirectionsService: AnyObject {
    func directions(from origin: CLLocationCoordinate2D,
                    to destination: CLLocationCoordinate2D) -> Single<DirectionsResult>
}

enum DirectionsError: Error { case noRoute }

final class MapKitDirectionsService: RouteDirectionsService {

    func directions(from origin: CLLocationCoordinate2D,
                    to destination: CLLocationCoordinate2D) -> Single<DirectionsResult> {
        Single.create { observer in
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .automobile

            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                guard let route = response?.routes.first else {
                    observer(.failure(error ?? DirectionsError.noRoute))
                    return
                }
                let pointCount = route.polyline.pointCount
                var coords = [CLLocationCoordinate2D](
                    repeating: .init(), count: pointCount
                )
                route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
                observer(.success(DirectionsResult(
                    polyline: coords,
                    distanceMeters: route.distance
                )))
            }
            return Disposables.create { directions.cancel() }
        }
    }
}

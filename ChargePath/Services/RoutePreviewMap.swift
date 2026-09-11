//
//  RoutePreviewMap.swift
//  ChargePath
//
//  Renders the Route Planner results screen's trip preview (polyline +
//  numbered charging stops). `GoogleRoutePreviewMap` draws it on a
//  `GMSMapView` (Google tiles + the real Google-computed route) whenever
//  `GOOGLE_MAPS_API_KEY` is configured; `AppleRoutePreviewMap` is the
//  `MKMapView` fallback with no key. `RoutePlannerViewController` only ever
//  talks to the `RoutePreviewMap` protocol.
//

import UIKit
import MapKit

protocol RoutePreviewMap: AnyObject {
    var view: UIView { get }
    func render(_ plan: RoutePlan)
}

enum RoutePreviewMapFactory {
    static func make() -> RoutePreviewMap {
        #if canImport(GoogleNavigation)
        if NavigationEngine.isConfigured {
            return GoogleRoutePreviewMap()
        }
        #endif
        return AppleRoutePreviewMap()
    }
}

/// Shared numbered-pin artwork for both map implementations.
enum StopBadge {
    static func image(number: Int) -> UIImage {
        let size = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let circle = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            AppColor.gold.setFill()
            context.cgContext.fillEllipse(in: circle)
            AppColor.ink.setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.strokeEllipse(in: circle)

            let text = "\(number)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: AppFont.slab(13, weight: .bold),
                .foregroundColor: AppColor.ink
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }
}

// MARK: - Apple (MapKit) fallback

final class AppleRoutePreviewMap: NSObject, RoutePreviewMap {

    private let mapView = MKMapView()
    var view: UIView { mapView }

    override init() {
        super.init()
        mapView.delegate = self
        mapView.isUserInteractionEnabled = true
    }

    func render(_ plan: RoutePlan) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        if plan.routeCoordinates.count > 1 {
            let polyline = MKPolyline(coordinates: plan.routeCoordinates, count: plan.routeCoordinates.count)
            mapView.addOverlay(polyline)
            mapView.setVisibleMapRect(
                polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32),
                animated: false
            )
        }
        mapView.addAnnotations(plan.stops.map { RouteStopAnnotation(stop: $0) })
    }
}

extension AppleRoutePreviewMap: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = AppColor.orange
        renderer.lineWidth = 5
        renderer.lineCap = .round
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let stop = annotation as? RouteStopAnnotation else { return nil }
        let id = "stop"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
            ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
        view.annotation = annotation
        let badge = StopBadge.image(number: stop.stop.index)
        view.image = badge
        view.frame = CGRect(origin: .zero, size: badge.size)
        return view
    }
}

private final class RouteStopAnnotation: NSObject, MKAnnotation {
    let stop: ChargingStop
    nonisolated var coordinate: CLLocationCoordinate2D { stop.station.coordinate }
    nonisolated init(stop: ChargingStop) {
        self.stop = stop
        super.init()
    }
}

// MARK: - Google Maps

#if canImport(GoogleNavigation)
import GoogleMaps

final class GoogleRoutePreviewMap: RoutePreviewMap {

    private let mapView = GMSMapView(frame: .zero)
    private var polyline: GMSPolyline?
    private var markers: [GMSMarker] = []

    var view: UIView { mapView }

    func render(_ plan: RoutePlan) {
        polyline?.map = nil
        markers.forEach { $0.map = nil }
        markers = []

        guard plan.routeCoordinates.count > 1 else { return }

        let path = GMSMutablePath()
        plan.routeCoordinates.forEach { path.add($0) }
        let line = GMSPolyline(path: path)
        line.strokeColor = AppColor.orange
        line.strokeWidth = 5
        line.map = mapView
        polyline = line

        for stop in plan.stops {
            let marker = GMSMarker(position: stop.station.coordinate)
            marker.icon = StopBadge.image(number: stop.index)
            marker.map = mapView
            markers.append(marker)
        }

        var bounds = GMSCoordinateBounds()
        for coordinate in plan.routeCoordinates {
            bounds = bounds.includingCoordinate(coordinate)
        }
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 32))
    }
}
#endif

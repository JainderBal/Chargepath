//
//  StationAnnotation.swift
//  ChargePath
//
//  Bridges a domain `Station` onto the real MKMapView. Replaces the mockup's
//  fake x/y-percentage pins with a proper MKAnnotation at real lat/long.
//

import MapKit

/// `nonisolated` throughout: MapKit calls these accessors from its own
/// context, and the app builds with `MainActor` default isolation.
final class StationAnnotation: NSObject, MKAnnotation {
    let station: Station
    nonisolated var coordinate: CLLocationCoordinate2D { station.coordinate }
    nonisolated var title: String? { station.name }
    nonisolated var subtitle: String? { station.address }

    nonisolated init(station: Station) {
        self.station = station
        super.init()
    }
}

/// Retro pin: gold circle + ink bolt, flips to orange when it's the selected
/// station (mockup `dotStyle`).
final class StationAnnotationView: MKAnnotationView {

    static let reuseID = "StationAnnotationView"

    private let bubble = UIView()
    private let bolt = UIImageView(image: UIImage(systemName: "bolt.fill"))

    override var annotation: MKAnnotation? {
        didSet { refresh() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 42, height: 42)
        centerOffset = CGPoint(x: 0, y: -21)

        bubble.frame = bounds
        bubble.layer.cornerRadius = 21
        bubble.layer.borderWidth = 2.5
        bubble.layer.borderColor = AppColor.ink.cgColor
        bubble.applyHardShadow(offsetY: 5, opacity: 1)
        addSubview(bubble)

        bolt.tintColor = AppColor.ink
        bolt.contentMode = .scaleAspectFit
        bolt.frame = bounds.insetBy(dx: 12, dy: 12)
        bubble.addSubview(bolt)

        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func refresh() {
        guard let station = (annotation as? StationAnnotation)?.station else { return }

        isAccessibilityElement = true
        accessibilityLabel = station.name
        accessibilityValue = station.isFullyOffline
            ? "All ports offline"
            : "\(station.availablePortCount) of \(station.ports.count) ports available"
        accessibilityTraits = .button

        if isSelected {
            bubble.backgroundColor = AppColor.orange
            bolt.tintColor = AppColor.cream
        } else {
            // Gold unless every port is confirmed offline (data without live
            // status reads as "not offline" so the map isn't a sea of grey).
            bubble.backgroundColor = station.isFullyOffline ? AppColor.sand : AppColor.gold
            bolt.tintColor = AppColor.ink
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        UIView.animate(withDuration: 0.25) {
            self.transform = selected
                ? CGAffineTransform(scaleX: 1.18, y: 1.18)
                : .identity
        }
        refresh()
    }
}

//
//  MapViewController.swift
//  ChargePath
//
//  The Map tab. A full-bleed real MKMapView with a floating search / filter
//  overlay. Annotations are plotted at real coordinates (replacing the
//  mockup's decorative x/y pins); all data-to-UI wiring goes through RxSwift
//  bindings on the injected MapViewModel.
//

import UIKit
import MapKit
import RxSwift
import RxRelay
import RxCocoa

final class MapViewController: UIViewController {

    private let viewModel: MapViewModel
    private let disposeBag = DisposeBag()

    private let mapView = MKMapView()
    private lazy var searchField = SearchFieldView(placeholder: viewModel.strings.value.searchPlaceholder)
    private lazy var segmentToggle = MorphingToggleView(titles: [
        viewModel.strings.value.segmentAll,
        viewModel.strings.value.segmentBookmarked
    ])
    private let filterButton = UIButton(type: .system)
    private let locateButton = UIButton(type: .system)
    private let resultLabel = UILabel(font: AppFont.slab(13, weight: .bold),
                                      color: AppColor.stone)
    private let bannerLabel = UILabel(font: AppFont.body(12, weight: .semibold),
                                      color: AppColor.ink, alignment: .center)
    private let chargingBanner = UIButton(type: .system)

    /// Bottom inset applied to the map while a sheet is open, so the focused
    /// pin stays visible in the strip above it (mockup's mapBottom / mapPan).
    private var sheetBottomInset: CGFloat = 0

    // ViewControllers receive a ready-made ViewModel — they never build one.
    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        setUpOverlay()
        setUpLocateButton()
        bind()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.onAppear()
    }

    // MARK: Layout

    private func setUpMap() {
        mapView.delegate = self
        // No MKMapView user-location dot: it spins up its own CLLocationManager
        // and would prompt. Location comes from the injected LocationService
        // (a fixed Montréal position in this build) — see LocationService.swift.
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.register(StationAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: StationAnnotationView.reuseID)
        mapView.register(StationClusterAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: StationClusterAnnotationView.reuseID)
        view.addAutoLayoutSubview(mapView)
        mapView.pinEdges(to: view)

        // Start over Montréal (matches the mockup's setting).
        let montreal = CLLocationCoordinate2D(latitude: 45.5230, longitude: -73.5870)
        mapView.setRegion(
            MKCoordinateRegion(center: montreal,
                               latitudinalMeters: 12_000,
                               longitudinalMeters: 12_000),
            animated: false
        )
    }

    private func setUpOverlay() {
        filterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
        filterButton.tintColor = AppColor.ink
        filterButton.backgroundColor = AppColor.parchment
        filterButton.applyInkOutline(cornerRadius: AppMetrics.minTapTarget / 2, clip: true)
        filterButton.widthAnchor.constraint(equalToConstant: AppMetrics.minTapTarget).isActive = true
        filterButton.heightAnchor.constraint(equalToConstant: AppMetrics.minTapTarget).isActive = true
        filterButton.accessibilityLabel = "Filters"

        searchField.textField.accessibilityLabel = "Search for a place or station"
        segmentToggle.accessibilityLabel = "Station list"

        bannerLabel.backgroundColor = AppColor.gold
        bannerLabel.applyInkOutline(cornerRadius: 999, clip: true)
        bannerLabel.numberOfLines = 2
        bannerLabel.isHidden = true
        bannerLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        bannerLabel.setContentHuggingPriority(.required, for: .vertical)

        let filterRow = UIStackView(axis: .horizontal, spacing: AppMetrics.space2,
                                    alignment: .center,
                                    arrangedSubviews: [segmentToggle, filterButton])

        let overlay = UIStackView(axis: .vertical, spacing: AppMetrics.space3,
                                  arrangedSubviews: [searchField, filterRow, resultLabel, bannerLabel])
        view.addAutoLayoutSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,
                                         constant: AppMetrics.space2),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space4),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space4)
        ])
    }

    private func setUpLocateButton() {
        locateButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        locateButton.tintColor = AppColor.ink
        locateButton.backgroundColor = AppColor.parchment
        locateButton.applyInkOutline(cornerRadius: AppMetrics.minTapTarget / 2, clip: true)
        locateButton.applyHardShadow(offsetY: 4, opacity: 0.2)
        locateButton.accessibilityLabel = "Centre on my location"
        view.addAutoLayoutSubview(locateButton)
        NSLayoutConstraint.activate([
            locateButton.widthAnchor.constraint(equalToConstant: AppMetrics.minTapTarget),
            locateButton.heightAnchor.constraint(equalToConstant: AppMetrics.minTapTarget),
            locateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space4),
            locateButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                 constant: -AppMetrics.space4)
        ])

        // "Charging now" banner — hidden unless a session is running.
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppColor.ink
        config.baseForegroundColor = AppColor.gold
        config.cornerStyle = .capsule
        config.image = UIImage(systemName: "bolt.fill")
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        config.titleLineBreakMode = .byTruncatingTail
        chargingBanner.configuration = config
        chargingBanner.isHidden = true
        chargingBanner.applyInkOutline(cornerRadius: 24)
        chargingBanner.applyHardShadow(offsetY: 5, opacity: 0.35)
        view.addAutoLayoutSubview(chargingBanner)
        NSLayoutConstraint.activate([
            chargingBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space4),
            chargingBanner.trailingAnchor.constraint(lessThanOrEqualTo: locateButton.leadingAnchor, constant: -AppMetrics.space2),
            chargingBanner.centerYAnchor.constraint(equalTo: locateButton.centerYAnchor)
        ])
    }

    // MARK: Bindings

    private func bind() {
        // Search text -> ViewModel (debounced so we don't refilter per keystroke).
        searchField.textField.rx.text.orEmpty
            .distinctUntilChanged()
            .debounce(.milliseconds(250), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak viewModel] in viewModel?.updateQuery($0) })
            .disposed(by: disposeBag)

        segmentToggle.onSelect = { [weak viewModel] index in
            viewModel?.setSegment(index == 0 ? .all : .bookmarked)
        }

        filterButton.rx.tap
            .subscribe(onNext: { [weak viewModel] in viewModel?.openFilters() })
            .disposed(by: disposeBag)

        locateButton.rx.tap
            .subscribe(onNext: { [weak viewModel] in viewModel?.locateTapped() })
            .disposed(by: disposeBag)

        chargingBanner.rx.tap
            .subscribe(onNext: { [weak viewModel] in viewModel?.openActiveSession() })
            .disposed(by: disposeBag)

        viewModel.activeSessionBanner
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] text in
                self?.chargingBanner.isHidden = (text == nil)
                if let text {
                    self?.chargingBanner.configuration?.title = text
                }
            })
            .disposed(by: disposeBag)

        viewModel.recenterOnUser
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] coordinate in
                self?.mapView.setCenter(coordinate, animated: true)
            })
            .disposed(by: disposeBag)

        // "Showing offline data" banner.
        viewModel.statusBanner
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] text in
                self?.bannerLabel.text = text.map { "  \($0)  " }
                self?.bannerLabel.isHidden = (text == nil)
            })
            .disposed(by: disposeBag)

        // Result count line.
        viewModel.resultLine
            .bind(to: resultLabel.rx.text)
            .disposed(by: disposeBag)

        // Visible stations -> map annotations. MKMapView has no bindable sink,
        // so we diff inside the subscription rather than reloadData().
        viewModel.visibleStations
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] stations in
                self?.render(stations: stations)
            })
            .disposed(by: disposeBag)

        // Live language changes retitle the static chrome.
        viewModel.strings
            .subscribe(onNext: { [weak self] strings in
                self?.searchField.textField.placeholder = strings.searchPlaceholder
                self?.segmentToggle.setTitles([strings.segmentAll, strings.segmentBookmarked])
            })
            .disposed(by: disposeBag)
    }

    private func render(stations: [Station]) {
        let existing = mapView.annotations.compactMap { $0 as? StationAnnotation }
        let existingIDs = Set(existing.map(\.station.id))
        let incomingIDs = Set(stations.map(\.id))

        let toRemove = existing.filter { !incomingIDs.contains($0.station.id) }
        mapView.removeAnnotations(toRemove)

        let toAdd = stations
            .filter { !existingIDs.contains($0.id) }
            .map(StationAnnotation.init)
        mapView.addAnnotations(toAdd)
    }

    // MARK: Sheet-aware focus (called by the coordinator)

    /// Shrink the usable map to the band above `sheetHeight` and centre the
    /// tapped station in it — the mockup's mapBottom + mapPan behaviour.
    func focus(on station: Station, sheetHeight: CGFloat) {
        sheetBottomInset = sheetHeight
        mapView.layoutMargins = UIEdgeInsets(top: 160, left: 24, bottom: sheetHeight, right: 24)
        let region = MKCoordinateRegion(center: station.coordinate,
                                        latitudinalMeters: 2_500,
                                        longitudinalMeters: 2_500)
        mapView.setRegion(mapView.regionThatFits(region), animated: true)

        // Deselect any previously-focused pin (tapping another pin while the
        // sheet is open), then select this one.
        mapView.selectedAnnotations
            .filter { ($0 as? StationAnnotation)?.station.id != station.id }
            .forEach { mapView.deselectAnnotation($0, animated: true) }

        if let annotation = mapView.annotations
            .compactMap({ $0 as? StationAnnotation })
            .first(where: { $0.station.id == station.id }) {
            mapView.selectAnnotation(annotation, animated: true)
        }
    }

    /// Restore the full-height map when the sheet closes.
    func endFocus() {
        sheetBottomInset = 0
        mapView.layoutMargins = .zero
        if let selected = mapView.selectedAnnotations.first {
            mapView.deselectAnnotation(selected, animated: true)
        }
    }
}

// MARK: - MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKClusterAnnotation {
            return mapView.dequeueReusableAnnotationView(
                withIdentifier: StationClusterAnnotationView.reuseID,
                for: annotation
            )
        }
        guard annotation is StationAnnotation else { return nil }   // keep the blue user dot
        return mapView.dequeueReusableAnnotationView(
            withIdentifier: StationAnnotationView.reuseID,
            for: annotation
        )
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let cluster = view.annotation as? MKClusterAnnotation {
            mapView.deselectAnnotation(cluster, animated: false)
            zoom(to: cluster)
            return
        }
        guard let station = (view.annotation as? StationAnnotation)?.station else { return }
        viewModel.selectStation(id: station.id)
    }

    /// Frames every member of a tapped cluster so the pile splits apart into
    /// individually-tappable pins.
    private func zoom(to cluster: MKClusterAnnotation) {
        var rect = MKMapRect.null
        for member in cluster.memberAnnotations {
            let point = MKMapPoint(member.coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        guard !rect.isNull else { return }
        mapView.setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 80, left: 80, bottom: 80, right: 80),
            animated: true
        )
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        viewModel.regionChanged(mapView.region)
    }
}

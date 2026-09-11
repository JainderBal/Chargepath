//
//  NavigationViewController.swift
//  ChargePath
//
//  Full-screen in-app turn-by-turn navigation. The map area is the Google
//  Navigation SDK's view (which renders its own maneuver header + footer);
//  ChargePath adds a themed ETA strip and an "End" button around it. When the
//  SDK isn't linked or has no API key, a themed placeholder takes the map's
//  place instead.
//

import UIKit
import RxSwift

final class NavigationViewController: UIViewController {

    private let viewModel: NavigationViewModel
    private let disposeBag = DisposeBag()

    private let mapContainer = UIView()
    private let placeholder = UILabel(font: AppFont.body(15), color: AppColor.stone, alignment: .center)

    private let destinationLabel = UILabel(font: AppFont.slab(13, weight: .bold), color: AppColor.stone)
    private let etaLabel = UILabel(font: AppFont.display(24))
    private let distanceLabel = UILabel(font: AppFont.body(14), color: AppColor.stone)
    private lazy var endButton = PillButton(title: viewModel.strings.value.navEndButton, style: .dark)

    init(viewModel: NavigationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.cream
        buildLayout()
        bind()

        // Create the navigation map + engine, embed it, then let the VM drive.
        let engine = NavigationEngine.make()
        embed(mapView: engine.mapView)
        viewModel.bind(navigator: engine.navigator)
    }

    // MARK: Layout

    private func buildLayout() {
        mapContainer.backgroundColor = AppColor.sand
        mapContainer.applyInkOutline(cornerRadius: AppMetrics.radiusCard, clip: true)
        view.addAutoLayoutSubview(mapContainer)

        placeholder.numberOfLines = 0
        placeholder.text = ""
        placeholder.isHidden = true
        mapContainer.addAutoLayoutSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.centerYAnchor.constraint(equalTo: mapContainer.centerYAnchor),
            placeholder.leadingAnchor.constraint(equalTo: mapContainer.leadingAnchor, constant: AppMetrics.space6),
            placeholder.trailingAnchor.constraint(equalTo: mapContainer.trailingAnchor, constant: -AppMetrics.space6)
        ])

        let etaBlock = UIStackView(axis: .vertical, spacing: 2,
                                   arrangedSubviews: [destinationLabel, etaLabel, distanceLabel])
        let card = UIStackView(axis: .horizontal, spacing: AppMetrics.space3,
                               arrangedSubviews: [etaBlock, UIView(), endButton])
        card.alignment = .center
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: AppMetrics.space4, left: AppMetrics.space5,
                                          bottom: AppMetrics.space4, right: AppMetrics.space5)
        card.backgroundColor = AppColor.parchment
        card.applyInkOutline(cornerRadius: AppMetrics.radiusCard)
        view.addAutoLayoutSubview(card)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            mapContainer.topAnchor.constraint(equalTo: guide.topAnchor, constant: AppMetrics.space4),
            mapContainer.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: AppMetrics.space4),
            mapContainer.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -AppMetrics.space4),

            card.topAnchor.constraint(equalTo: mapContainer.bottomAnchor, constant: AppMetrics.space4),
            card.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: AppMetrics.space4),
            card.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -AppMetrics.space4),
            card.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -AppMetrics.space4)
        ])

        endButton.onTap = { [weak self] in self?.viewModel.stop() }
    }

    private func embed(mapView: UIView) {
        mapContainer.insertSubview(mapView, belowSubview: placeholder)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: mapContainer.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapContainer.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapContainer.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapContainer.trailingAnchor)
        ])
    }

    // MARK: Bindings

    private func bind() {
        viewModel.destinationName
            .map { name in name.isEmpty ? "" : "→ \(name)" }
            .bind(to: destinationLabel.rx.text)
            .disposed(by: disposeBag)

        viewModel.etaText.bind(to: etaLabel.rx.text).disposed(by: disposeBag)
        viewModel.distanceText.bind(to: distanceLabel.rx.text).disposed(by: disposeBag)

        viewModel.unavailableText
            .subscribe(onNext: { [weak self] text in
                self?.placeholder.text = text
                self?.placeholder.isHidden = text == nil
            })
            .disposed(by: disposeBag)

        viewModel.strings
            .subscribe(onNext: { [weak self] strings in
                self?.endButton.setTitle(strings.navEndButton, for: .normal)
            })
            .disposed(by: disposeBag)
    }
}

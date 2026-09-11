//
//  StationDetailViewController.swift
//  ChargePath
//
//  The Station Detail bottom sheet (presented with UISheetPresentationController
//  .medium()/.large() detents by the coordinator). Live port status, connector
//  badges, bookmark star and the "Start charging" CTA. All content is driven
//  by RxSwift bindings on StationDetailViewModel.
//

import UIKit
import RxSwift
import RxRelay

final class StationDetailViewController: UIViewController {

    private let viewModel: StationDetailViewModel
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let content = UIStackView(axis: .vertical, spacing: AppMetrics.space4)

    private let nameLabel = UILabel(font: AppFont.display(26))
    private let addressLabel = UILabel(font: AppFont.body(14), color: AppColor.stone)
    private let distanceLabel = UILabel(font: AppFont.body(14), color: AppColor.stone)
    private let bookmarkButton = UIButton(type: .system)
    private let directionsButton = UIButton(type: .system)
    private let connectorRow = UIStackView(axis: .horizontal, spacing: 6)
    private let liveDot = UIView()
    private let liveLabel = UILabel(font: AppFont.body(12), color: AppColor.stone)
    private let portsStack = UIStackView(axis: .vertical, spacing: AppMetrics.space2)
    private let updatedLabel = UILabel(font: AppFont.body(12), color: AppColor.stone)
    private lazy var startButton = PillButton(title: viewModel.strings.value.stationStartCharging)

    init(viewModel: StationDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.cream
        buildLayout()
        bind()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        viewModel.onAppear()
    }

    // MARK: Layout

    private func buildLayout() {
        view.addAutoLayoutSubview(scrollView)
        scrollView.pinEdges(to: view)
        scrollView.addAutoLayoutSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor,
                                         constant: AppMetrics.space5),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space5),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space5),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                                            constant: -AppMetrics.space6)
        ])

        // Header: title block + bookmark star.
        addressLabel.numberOfLines = 2
        let titleBlock = UIStackView(axis: .vertical, spacing: AppMetrics.space1,
                                     arrangedSubviews: [nameLabel, addressLabel, distanceLabel])
        titleBlock.setContentHuggingPriority(.defaultLow, for: .horizontal)

        bookmarkButton.setImage(UIImage(systemName: "star.fill"), for: .normal)
        bookmarkButton.tintColor = AppColor.cream
        bookmarkButton.backgroundColor = AppColor.parchment
        bookmarkButton.applyInkOutline(cornerRadius: 23, clip: true)
        bookmarkButton.widthAnchor.constraint(equalToConstant: 46).isActive = true
        bookmarkButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        bookmarkButton.addTarget(self, action: #selector(toggleBookmark), for: .touchUpInside)
        bookmarkButton.accessibilityLabel = "Bookmark this station"

        directionsButton.setImage(UIImage(systemName: "arrow.triangle.turn.up.right.circle.fill"), for: .normal)
        directionsButton.tintColor = AppColor.ink
        directionsButton.backgroundColor = AppColor.parchment
        directionsButton.applyInkOutline(cornerRadius: 23, clip: true)
        directionsButton.widthAnchor.constraint(equalToConstant: 46).isActive = true
        directionsButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        directionsButton.addTarget(self, action: #selector(startNavigation), for: .touchUpInside)
        directionsButton.accessibilityLabel = viewModel.strings.value.stationDirections

        let header = UIStackView(axis: .horizontal, spacing: AppMetrics.space3,
                                 alignment: .top,
                                 arrangedSubviews: [titleBlock, directionsButton, bookmarkButton])
        content.addArrangedSubview(header)
        content.addArrangedSubview(connectorRow)

        // "Charging ports" section header with the live indicator.
        liveDot.widthAnchor.constraint(equalToConstant: 9).isActive = true
        liveDot.heightAnchor.constraint(equalToConstant: 9).isActive = true
        liveDot.layer.cornerRadius = 4.5
        let portsHeaderLabel = UILabel(text: viewModel.strings.value.stationPortsHeader,
                                       font: AppFont.slab(13, weight: .bold),
                                       color: AppColor.stone)
        let rule = UIView()
        rule.backgroundColor = AppColor.sand
        rule.heightAnchor.constraint(equalToConstant: 2).isActive = true
        rule.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let portsHeader = UIStackView(axis: .horizontal, spacing: AppMetrics.space2,
                                      alignment: .center,
                                      arrangedSubviews: [portsHeaderLabel, rule, liveDot, liveLabel])
        content.addArrangedSubview(portsHeader)
        content.addArrangedSubview(portsStack)
        content.addArrangedSubview(updatedLabel)

        startButton.onTap = { [weak viewModel] in viewModel?.startCharging() }
        content.addArrangedSubview(startButton)
    }

    // MARK: Bindings

    private func bind() {
        viewModel.station
            .subscribe(onNext: { [weak self] station in
                self?.renderStation(station)
            })
            .disposed(by: disposeBag)

        viewModel.isBookmarked
            .subscribe(onNext: { [weak self] on in
                self?.bookmarkButton.tintColor = on ? AppColor.gold : AppColor.cream
                self?.bookmarkButton.backgroundColor = on ? AppColor.ink : AppColor.parchment
            })
            .disposed(by: disposeBag)

        Observable.combineLatest(viewModel.liveState, viewModel.strings)
            .subscribe(onNext: { [weak self] state, strings in
                let checking = state == .checking
                self?.liveDot.backgroundColor = checking ? AppColor.gold : AppColor.available
                self?.liveLabel.text = checking ? strings.stationCheckingStatus : strings.stationLive
                self?.updatedLabel.text = checking
                    ? strings.stationCheckingStatus + "…"
                    : strings.stationStatusUpdated
            })
            .disposed(by: disposeBag)

        Observable.combineLatest(viewModel.startEnabled, viewModel.startTitle)
            .subscribe(onNext: { [weak self] enabled, title in
                self?.startButton.setTitle(title, for: .normal)
                self?.startButton.setEnabledStyle(enabled)
            })
            .disposed(by: disposeBag)
    }

    private func renderStation(_ station: Station) {
        nameLabel.text = station.name
        addressLabel.text = station.address
        distanceLabel.text = station.distanceFromUser.map { Self.distanceText($0) }
        distanceLabel.isHidden = station.distanceFromUser == nil

        let vehicleConnector = viewModel.vehicleConnector.value
        connectorRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for connector in station.connectors {
            let chip = ChipView(text: connector == vehicleConnector
                                ? "\(connector.displayName) · fits your car"
                                : connector.displayName)
            chip.isOn = connector == vehicleConnector
            chip.isUserInteractionEnabled = false
            connectorRow.addArrangedSubview(chip)
        }
        connectorRow.addArrangedSubview(UIView())   // left-align chips

        let checking = viewModel.liveState.value == .checking
        portsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for port in station.ports {
            portsStack.addArrangedSubview(PortRowView(port: port, checking: checking))
        }
    }

    private static func distanceText(_ meters: Double) -> String {
        meters < 1000
            ? "\(Int(meters)) m away"
            : String(format: "%.1f km away", meters / 1000)
    }

    @objc private func toggleBookmark() { viewModel.toggleBookmark() }
    @objc private func startNavigation() { viewModel.startNavigation() }
}

//
//  RoutePlannerViewController.swift
//  ChargePath
//
//  The Route tab — a two-stage flow bound to RoutePlannerViewModel.stage:
//    .input   → trip form (start / destination / vehicle range)
//    .results → a RoutePreviewMap (Google Maps when keyed, MapKit fallback)
//               with the driving polyline + numbered charging stops, and a
//               list of those stops below.
//

import UIKit
import RxSwift
import RxRelay
import RxCocoa

final class RoutePlannerViewController: UIViewController {

    private let viewModel: RoutePlannerViewModel
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let stripes = StripeBackgroundView()

    // Input stage
    private let inputContainer = UIStackView(axis: .vertical, spacing: AppMetrics.space4)
    private let originField = UITextField()
    private let destinationField = UITextField()
    private let vehicleLineLabel = UILabel(font: AppFont.slab(17, weight: .bold))
    private lazy var planButton = PillButton(title: viewModel.strings.value.routePlanButton, style: .dark)
    private let hintLabel = UILabel(font: AppFont.body(13), color: AppColor.stone, alignment: .center)
    private let inputHeadingLabel = UILabel(font: AppFont.display(30))
    private let vehicleCaptionLabel = UILabel(font: AppFont.body(13), color: AppColor.stone)
    private let editVehicleButton = UIButton(type: .system)

    // Results stage
    private let resultsContainer = UIStackView(axis: .vertical, spacing: AppMetrics.space4)
    private lazy var previewMap: RoutePreviewMap = RoutePreviewMapFactory.make()
    private let routeTitleLabel = UILabel(font: AppFont.slab(22, weight: .bold))
    private let routeMetaLabel = UILabel(font: AppFont.body(13), color: AppColor.stone)
    private let estimateNote = UILabel(
        text: "  Offline estimate — couldn't reach routing. Distances and times are illustrative.  ",
        font: AppFont.body(12, weight: .semibold), color: AppColor.ink)
    private let stopsStack = UIStackView(axis: .vertical, spacing: AppMetrics.space3)
    private lazy var navButton = PillButton(title: viewModel.strings.value.navStartButton, style: .primary)

    init(viewModel: RoutePlannerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.cream
        scrollView.contentInsetAdjustmentBehavior = .always
        buildLayout()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Custom heading + back buttons — no system nav bar on this screen.
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: Layout

    private func buildLayout() {
        stripes.angleDegrees = -18
        view.addAutoLayoutSubview(stripes)
        NSLayoutConstraint.activate([
            stripes.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stripes.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stripes.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stripes.heightAnchor.constraint(equalToConstant: 240)
        ])

        view.addAutoLayoutSubview(scrollView)
        scrollView.pinEdges(to: view)

        let root = UIStackView(axis: .vertical, arrangedSubviews: [inputContainer, resultsContainer])
        scrollView.addAutoLayoutSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppMetrics.space6),
            root.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppMetrics.space8),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space5),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space5)
        ])

        buildInputStage()
        buildResultsStage()
    }

    private func buildInputStage() {
        [originField, destinationField].forEach {
            $0.font = AppFont.body(16)
            $0.textColor = AppColor.ink
            $0.autocorrectionType = .no
        }
        // Seed the fields from the ViewModel's initial trip (editable after).
        originField.text = viewModel.originText.value
        destinationField.text = viewModel.destinationText.value

        let fieldsCard = OutlinedCardView()
        fieldsCard.contentStack.spacing = AppMetrics.space2
        fieldsCard.contentStack.addArrangedSubview(fieldRow(dotColor: AppColor.sky, field: originField))
        let divider = UIView(); divider.backgroundColor = AppColor.sand
        divider.heightAnchor.constraint(equalToConstant: 2).isActive = true
        fieldsCard.contentStack.addArrangedSubview(divider)
        fieldsCard.contentStack.addArrangedSubview(fieldRow(dotColor: AppColor.orange, field: destinationField))

        // Vehicle profile row.
        let bolt = UIImageView(image: UIImage(systemName: "bolt.fill"))
        bolt.tintColor = AppColor.ink
        bolt.setContentHuggingPriority(.required, for: .horizontal)
        let vehText = UIStackView(axis: .vertical, spacing: 2, arrangedSubviews: [vehicleCaptionLabel, vehicleLineLabel])
        vehText.setContentHuggingPriority(.defaultLow, for: .horizontal)
        editVehicleButton.setTitleColor(AppColor.orange, for: .normal)
        editVehicleButton.titleLabel?.font = AppFont.body(14, weight: .semibold)
        editVehicleButton.addTarget(self, action: #selector(editVehicle), for: .touchUpInside)
        let vehicleRow = OutlinedCardView(fill: AppColor.sand, cornerRadius: 22, contentInset: AppMetrics.space4, shadowOffsetY: 0)
        vehicleRow.contentStack.axis = .horizontal
        vehicleRow.contentStack.alignment = .center
        vehicleRow.contentStack.spacing = AppMetrics.space3
        [bolt, vehText, editVehicleButton].forEach { vehicleRow.contentStack.addArrangedSubview($0) }

        planButton.onTap = { [weak viewModel] in viewModel?.planTrip() }

        [inputHeadingLabel, fieldsCard, vehicleRow, planButton, hintLabel]
            .forEach { inputContainer.addArrangedSubview($0) }
    }

    private func buildResultsStage() {
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = AppColor.ink
        backButton.backgroundColor = AppColor.parchment
        backButton.applyInkOutline(cornerRadius: AppMetrics.minTapTarget / 2)
        backButton.widthAnchor.constraint(equalToConstant: AppMetrics.minTapTarget).isActive = true
        backButton.heightAnchor.constraint(equalToConstant: AppMetrics.minTapTarget).isActive = true
        backButton.addTarget(self, action: #selector(backToInput), for: .touchUpInside)

        let mapView = previewMap.view
        mapView.applyInkOutline(cornerRadius: AppMetrics.radiusCard)
        mapView.layer.masksToBounds = true
        mapView.heightAnchor.constraint(equalToConstant: 220).isActive = true

        backButton.accessibilityLabel = "Back to trip input"

        let titleRow = UIStackView(axis: .horizontal, alignment: .firstBaseline,
                                   arrangedSubviews: [routeTitleLabel, routeMetaLabel])
        routeTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        estimateNote.backgroundColor = AppColor.sand
        estimateNote.applyInkOutline(cornerRadius: AppMetrics.radiusChip, clip: true)
        estimateNote.numberOfLines = 0
        estimateNote.isHidden = true

        navButton.onTap = { [weak viewModel] in viewModel?.startNavigation() }

        [backButton, mapView, titleRow, estimateNote, navButton, stopsStack]
            .forEach { resultsContainer.addArrangedSubview($0) }
        resultsContainer.setCustomSpacing(AppMetrics.space3, after: backButton)
    }

    private func fieldRow(dotColor: UIColor, field: UITextField) -> UIView {
        let dot = UIView()
        dot.backgroundColor = dotColor
        dot.layer.cornerRadius = 6
        dot.widthAnchor.constraint(equalToConstant: 12).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 12).isActive = true
        let row = UIStackView(axis: .horizontal, spacing: AppMetrics.space3,
                              alignment: .center, arrangedSubviews: [dot, field])
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        return row
    }

    // MARK: Bindings

    private func bind() {
        originField.rx.text.orEmpty.distinctUntilChanged()
            .subscribe(onNext: { [weak viewModel] in viewModel?.setOrigin($0) })
            .disposed(by: disposeBag)
        destinationField.rx.text.orEmpty.distinctUntilChanged()
            .subscribe(onNext: { [weak viewModel] in viewModel?.setDestination($0) })
            .disposed(by: disposeBag)

        viewModel.vehicleLine.bind(to: vehicleLineLabel.rx.text).disposed(by: disposeBag)
        viewModel.routeMeta.bind(to: routeMetaLabel.rx.text).disposed(by: disposeBag)

        viewModel.stage
            .subscribe(onNext: { [weak self] stage in
                self?.inputContainer.isHidden = stage != .input
                self?.resultsContainer.isHidden = stage != .results
            })
            .disposed(by: disposeBag)

        viewModel.strings
            .subscribe(onNext: { [weak self] strings in
                self?.routeTitleLabel.text = strings.routeResultsTitle
                self?.navButton.setTitle(strings.navStartButton, for: .normal)
                self?.inputHeadingLabel.text = strings.routeInputHeading
                self?.originField.placeholder = strings.routeStartPlaceholder
                self?.destinationField.placeholder = strings.routeDestinationPlaceholder
                self?.vehicleCaptionLabel.text = strings.routeVehicleProfileCaption
                self?.editVehicleButton.setTitle(strings.routeEditVehicle, for: .normal)
                self?.hintLabel.text = strings.routePlanHint
            })
            .disposed(by: disposeBag)

        Observable.combineLatest(viewModel.isPlanning, viewModel.strings)
            .subscribe(onNext: { [weak self] planning, strings in
                self?.planButton.setTitle(
                    planning ? strings.routePlanningButton : strings.routePlanButton, for: .normal)
                self?.planButton.isEnabled = !planning
            })
            .disposed(by: disposeBag)

        viewModel.plan
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] plan in self?.renderPlan(plan) })
            .disposed(by: disposeBag)
    }

    private func renderPlan(_ plan: RoutePlan) {
        estimateNote.isHidden = !plan.isEstimate
        previewMap.render(plan)

        // List.
        stopsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for stop in plan.stops {
            let row = RouteStopRowView(stop: stop)
            row.onTap = { [weak viewModel] in viewModel?.selectStop(stop) }
            stopsStack.addArrangedSubview(row)
        }
    }

    // MARK: Actions

    @objc private func editVehicle() { viewModel.editVehicle() }
    @objc private func backToInput() { viewModel.backToInput() }
}

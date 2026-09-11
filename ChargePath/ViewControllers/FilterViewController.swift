//
//  FilterViewController.swift
//  ChargePath
//
//  The Filter bottom sheet: connector chips, availability / charging-speed
//  option rows, a radius segmented control, and two switches (compatible-only,
//  hide-offline). Edits a working StationFilter copy on FilterViewModel and
//  commits it back to the Map screen on dismiss.
//

import UIKit
import RxSwift
import RxRelay

final class FilterViewController: UIViewController {

    private let viewModel: FilterViewModel
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let stack = UIStackView(axis: .vertical, spacing: AppMetrics.space5)

    private let connectorRow = UIStackView(axis: .horizontal, spacing: AppMetrics.space2)
    private let availabilityRow = UIStackView(axis: .horizontal, spacing: AppMetrics.space2)
    private let powerRow = UIStackView(axis: .horizontal, spacing: AppMetrics.space2)
    private let radiusRow = UIStackView(axis: .horizontal, spacing: AppMetrics.space2)
    private let compatibleSwitch = UISwitch()
    private let hideOfflineSwitch = UISwitch()

    init(viewModel: FilterViewModel) {
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Any dismissal (swipe or "Apply") pushes the working copy back.
        viewModel.commit()
    }

    // MARK: Layout

    private func buildLayout() {
        view.addAutoLayoutSubview(scrollView)
        scrollView.pinEdges(to: view)
        scrollView.addAutoLayoutSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppMetrics.space6),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppMetrics.space6),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space5),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space5)
        ])

        let s = viewModel.strings.value

        let resetButton = UIButton(type: .system)
        resetButton.setTitle(s.filtersReset, for: .normal)
        resetButton.setTitleColor(AppColor.orange, for: .normal)
        resetButton.titleLabel?.font = AppFont.body(14, weight: .semibold)
        resetButton.addTarget(self, action: #selector(reset), for: .touchUpInside)
        let titleLabel = UILabel(text: s.filtersTitle, font: AppFont.display(24))
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(UIStackView(axis: .horizontal, alignment: .center,
                                             arrangedSubviews: [titleLabel, resetButton]))

        stack.addArrangedSubview(section(s.filterConnectorType, connectorRow))
        stack.addArrangedSubview(section(s.filterAvailability, availabilityRow))
        stack.addArrangedSubview(section(s.filterChargingSpeed, powerRow))
        stack.addArrangedSubview(section(s.filterSearchRadius, radiusRow))
        stack.addArrangedSubview(switchRow(s.filterCompatibleOnly, nil, compatibleSwitch))
        stack.addArrangedSubview(switchRow(s.filterHideOfflineTitle, s.filterHideOfflineBody, hideOfflineSwitch))

        let apply = PillButton(title: s.filterApply, style: .dark)
        apply.onTap = { [weak self] in self?.dismiss(animated: true) }
        stack.addArrangedSubview(apply)

        compatibleSwitch.onTintColor = AppColor.available
        hideOfflineSwitch.onTintColor = AppColor.sky
        compatibleSwitch.addTarget(self, action: #selector(compatChanged), for: .valueChanged)
        hideOfflineSwitch.addTarget(self, action: #selector(hideOfflineChanged), for: .valueChanged)

        buildConnectorChips()
        buildAvailabilityChips(s)
        buildPowerChips(s)
        buildRadiusChips(s)
    }

    private func section(_ title: String, _ contentRow: UIView) -> UIView {
        let label = UILabel(text: title.uppercased(),
                            font: AppFont.slab(13, weight: .bold), color: AppColor.stone)
        let wrap = UIStackView(axis: .vertical, spacing: AppMetrics.space2,
                               arrangedSubviews: [label, contentRow])
        contentRow.setContentHuggingPriority(.required, for: .vertical)
        return wrap
    }

    private func switchRow(_ title: String, _ subtitle: String?, _ toggle: UISwitch) -> UIView {
        let titleLabel = UILabel(text: title, font: AppFont.slab(16, weight: .semibold))
        let textStack = UIStackView(axis: .vertical, spacing: 2, arrangedSubviews: [titleLabel])
        if let subtitle {
            textStack.addArrangedSubview(UILabel(text: subtitle, font: AppFont.body(13), color: AppColor.stone))
        }
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let card = OutlinedCardView(fill: AppColor.parchment, cornerRadius: AppMetrics.radiusChip,
                                    contentInset: AppMetrics.space4, shadowOffsetY: 0)
        card.contentStack.axis = .horizontal
        card.contentStack.alignment = .center
        card.contentStack.spacing = AppMetrics.space3
        card.contentStack.addArrangedSubview(textStack)
        card.contentStack.addArrangedSubview(toggle)
        return card
    }

    // MARK: Chip builders

    private func buildConnectorChips() {
        for connector in [Connector.ccs, .nacs, .j1772] {
            let chip = ChipView(text: connector.displayName)
            chip.onTap = { [weak self] in self?.viewModel.toggleConnector(connector) }
            chip.tag = connectorTag(connector)
            connectorRow.addArrangedSubview(chip)
        }
        connectorRow.addArrangedSubview(UIView())
    }

    private func buildAvailabilityChips(_ s: Strings) {
        let options: [(StationFilter.Availability, String)] = [
            (.any, s.optAny), (.oneFree, s.optAvailableNow), (.twoFree, s.optTwoPortsFree)
        ]
        for (value, label) in options {
            let chip = ChipView(text: label)
            chip.onTap = { [weak self] in self?.viewModel.setAvailability(value) }
            chip.accessibilityValue = "\(value)"
            availabilityRow.addArrangedSubview(chip)
        }
        availabilityRow.addArrangedSubview(UIView())
    }

    private func buildPowerChips(_ s: Strings) {
        let options: [(StationFilter.Power, String)] = [
            (.any, s.optAny), (.level2, s.optLevel2), (.fast, "150 kW+"), (.ultra, "250 kW+")
        ]
        for (value, label) in options {
            let chip = ChipView(text: label)
            chip.onTap = { [weak self] in self?.viewModel.setPower(value) }
            chip.accessibilityValue = "\(value)"
            powerRow.addArrangedSubview(chip)
        }
        powerRow.addArrangedSubview(UIView())
    }

    private func buildRadiusChips(_ s: Strings) {
        for km in viewModel.radiusOptions {
            let chip = ChipView(text: km >= 100 ? s.optRadiusAny : "\(km) km")
            chip.onTap = { [weak self] in self?.viewModel.setRadius(km) }
            chip.accessibilityValue = "\(km)"
            radiusRow.addArrangedSubview(chip)
        }
        radiusRow.addArrangedSubview(UIView())
    }

    // MARK: Bindings

    private func bind() {
        viewModel.draft
            .subscribe(onNext: { [weak self] filter in
                self?.applyDraftToControls(filter)
            })
            .disposed(by: disposeBag)
    }

    private func applyDraftToControls(_ filter: StationFilter) {
        for case let chip as ChipView in connectorRow.arrangedSubviews {
            let connector = connectorFromTag(chip.tag)
            chip.isOn = filter.connectors.contains(connector)
        }
        setChipStates(availabilityRow, selected: "\(filter.availability)")
        setChipStates(powerRow, selected: "\(filter.power)")
        setChipStates(radiusRow, selected: "\(filter.radiusKm)")
        compatibleSwitch.isOn = filter.compatibleOnly
        hideOfflineSwitch.isOn = filter.hideOffline
    }

    private func setChipStates(_ row: UIStackView, selected: String) {
        for case let chip as ChipView in row.arrangedSubviews {
            chip.isOn = chip.accessibilityValue == selected
        }
    }

    // MARK: Actions

    @objc private func reset() { viewModel.reset() }
    @objc private func compatChanged() { viewModel.setCompatibleOnly(compatibleSwitch.isOn) }
    @objc private func hideOfflineChanged() { viewModel.setHideOffline(hideOfflineSwitch.isOn) }

    // Tag helpers so connector chips can be looked up without a dictionary.
    private func connectorTag(_ c: Connector) -> Int {
        switch c { case .ccs: return 1; case .nacs: return 2; case .j1772: return 3; case .unknown: return 0 }
    }
    private func connectorFromTag(_ tag: Int) -> Connector {
        switch tag { case 1: return .ccs; case 2: return .nacs; case 3: return .j1772; default: return .unknown }
    }
}

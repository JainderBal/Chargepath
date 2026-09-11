//
//  VehicleSelectionViewController.swift
//  ChargePath
//
//  Screen 6 — connector-compatible vehicle picker. Reachable from both
//  Settings and the Route Planner. A list of catalogue vehicles with the
//  current pick marked, plus "or pick a connector" manual chips.
//

import UIKit
import RxSwift
import RxRelay

final class VehicleSelectionViewController: UIViewController {

    private let viewModel: VehicleSelectionViewModel
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let vehicleList = UIStackView(axis: .vertical, spacing: AppMetrics.space2)
    private let connectorRow = UIStackView(axis: .horizontal, spacing: AppMetrics.space2)

    init(viewModel: VehicleSelectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.cream
        title = viewModel.strings.value.settingsVehicleProfile
        buildLayout()
        bind()
    }

    private func buildLayout() {
        let s = viewModel.strings.value
        let heading = UILabel(text: s.vehicleTitle, font: AppFont.display(28))
        let body = UILabel(text: s.vehicleBody, font: AppFont.body(14), color: AppColor.stone)
        let manualCaption = UILabel(text: s.vehicleOrPickConnector.uppercased(),
                                    font: AppFont.slab(13, weight: .bold), color: AppColor.stone)
        connectorRow.addArrangedSubview(UIView())   // trailing spacer added after chips

        let stack = UIStackView(axis: .vertical, spacing: AppMetrics.space5,
                                arrangedSubviews: [heading, body, vehicleList, manualCaption, connectorRow])
        view.addAutoLayoutSubview(scrollView)
        scrollView.pinEdges(to: view)
        scrollView.addAutoLayoutSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppMetrics.space5),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppMetrics.space8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space5),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space5)
        ])
    }

    private func bind() {
        viewModel.vehicleRows
            .subscribe(onNext: { [weak self] rows in self?.renderVehicles(rows) })
            .disposed(by: disposeBag)

        viewModel.connectorChips
            .subscribe(onNext: { [weak self] chips in self?.renderConnectors(chips) })
            .disposed(by: disposeBag)
    }

    private func renderVehicles(_ rows: [VehicleRow]) {
        vehicleList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for row in rows {
            let card = OutlinedCardView(fill: row.isSelected ? AppColor.gold : AppColor.parchment,
                                        cornerRadius: 22, contentInset: AppMetrics.space4, shadowOffsetY: 0)
            card.contentStack.axis = .horizontal
            card.contentStack.alignment = .center
            card.contentStack.spacing = AppMetrics.space3

            let name = UILabel(text: row.vehicle.name, font: AppFont.slab(18, weight: .bold))
            let sub = UILabel(text: row.vehicle.subtitle, font: AppFont.body(13), color: AppColor.stone)
            let text = UIStackView(axis: .vertical, spacing: 2, arrangedSubviews: [name, sub])
            text.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let dot = UIView()
            dot.applyInkOutline(cornerRadius: 11, clip: true)
            dot.backgroundColor = row.isSelected ? AppColor.orange : .clear
            dot.widthAnchor.constraint(equalToConstant: 22).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 22).isActive = true

            card.contentStack.addArrangedSubview(text)
            card.contentStack.addArrangedSubview(dot)
            card.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(vehicleTapped(_:)))
            card.addGestureRecognizer(tap)
            card.tag = rows.firstIndex(where: { $0.vehicle.id == row.vehicle.id }) ?? 0
            vehicleList.addArrangedSubview(card)
        }
        currentRows = rows
    }

    private func renderConnectors(_ chips: [ConnectorChip]) {
        connectorRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for chip in chips {
            let view = ChipView(text: chip.connector.displayName)
            view.isOn = chip.isSelected
            view.onTap = { [weak viewModel] in viewModel?.selectConnector(chip.connector) }
            connectorRow.addArrangedSubview(view)
        }
        connectorRow.addArrangedSubview(UIView())
    }

    private var currentRows: [VehicleRow] = []

    @objc private func vehicleTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag, currentRows.indices.contains(index) else { return }
        viewModel.select(currentRows[index].vehicle)
    }
}

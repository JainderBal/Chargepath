//
//  ActivateChargingViewController.swift
//  ChargePath
//
//  The full-screen Activate flow presented over the Station Detail sheet.
//  Two steps — select port → confirm (places the pre-auth hold and starts a
//  session) — bound to ActivateChargingViewModel.step. On start the coordinator
//  swaps this for the live ActiveSession screen.
//

import UIKit
import RxSwift
import RxRelay

final class ActivateChargingViewController: UIViewController {

    private let viewModel: ActivateChargingViewModel
    private let disposeBag = DisposeBag()

    private let titleLabel = UILabel(font: AppFont.slab(18, weight: .bold))
    private let testModeBadge = UILabel(font: AppFont.body(11, weight: .bold),
                                        color: AppColor.gold, alignment: .center)
    private let container = UIStackView(axis: .vertical, spacing: AppMetrics.space4)

    init(viewModel: ActivateChargingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.cream
        buildChrome()
        bind()
    }

    private func buildChrome() {
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = AppColor.ink
        closeButton.backgroundColor = AppColor.parchment
        closeButton.applyInkOutline(cornerRadius: AppMetrics.minTapTarget / 2, clip: true)
        closeButton.widthAnchor.constraint(equalToConstant: AppMetrics.minTapTarget).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: AppMetrics.minTapTarget).isActive = true
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        closeButton.accessibilityLabel = "Close"

        testModeBadge.backgroundColor = AppColor.ink
        testModeBadge.layer.cornerRadius = 12
        testModeBadge.layer.masksToBounds = true
        testModeBadge.setContentHuggingPriority(.required, for: .horizontal)
        testModeBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        testModeBadge.text = "  \(viewModel.strings.value.testModeBadge)  "

        let header = UIStackView(axis: .horizontal, spacing: AppMetrics.space3,
                                 alignment: .center,
                                 arrangedSubviews: [closeButton, titleLabel, testModeBadge])
        view.addAutoLayoutSubview(header)
        view.addAutoLayoutSubview(container)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppMetrics.space4),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space5),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space5),
            container.topAnchor.constraint(equalTo: header.bottomAnchor, constant: AppMetrics.space6),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space5),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space5)
        ])
    }

    private func bind() {
        Observable.combineLatest(viewModel.step, viewModel.strings,
                                 viewModel.selectedPort, viewModel.isProcessing,
                                 viewModel.insufficientFunds)
            .subscribe(onNext: { [weak self] step, strings, port, processing, funds in
                self?.titleLabel.text = strings.activateTitle
                self?.render(step: step, strings: strings, selectedPort: port,
                             processing: processing, insufficientFunds: funds)
            })
            .disposed(by: disposeBag)
    }

    // MARK: Step rendering

    private func render(step: ActivateChargingStep,
                        strings: Strings,
                        selectedPort: ChargingPort?,
                        processing: Bool,
                        insufficientFunds: String?) {
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch step {
        case .selectPort:
            container.addArrangedSubview(makeSelectStep(strings: strings, selectedPort: selectedPort))
        case .confirmPayment:
            container.addArrangedSubview(makePayStep(strings: strings, processing: processing,
                                                     insufficientFunds: insufficientFunds))
        }
    }

    private func makeSelectStep(strings: Strings, selectedPort: ChargingPort?) -> UIView {
        let heading = UILabel(text: strings.activateSelectHeading, font: AppFont.display(24))
        let list = UIStackView(axis: .vertical, spacing: AppMetrics.space2)
        for port in viewModel.selectablePorts {
            let row = SelectablePortRow(port: port, isSelected: port.id == selectedPort?.id)
            row.onTap = { [weak viewModel] in viewModel?.selectPort(port) }
            list.addArrangedSubview(row)
        }
        let cta = PillButton(title: strings.activateContinueButton)
        cta.setEnabledStyle(selectedPort != nil)
        cta.onTap = { [weak viewModel] in viewModel?.continueToPayment() }
        return UIStackView(axis: .vertical, spacing: AppMetrics.space5,
                           arrangedSubviews: [heading, list, cta])
    }

    private func makePayStep(strings: Strings, processing: Bool, insufficientFunds: String?) -> UIView {
        let heading = UILabel(text: strings.activatePayHeading, font: AppFont.display(24))

        let card = OutlinedCardView()
        card.contentStack.addArrangedSubview(summaryRow(strings.labelStation, viewModel.stationName))
        card.contentStack.addArrangedSubview(summaryRow(strings.labelPort,
                                                        viewModel.selectedPort.value?.label ?? "—"))
        card.contentStack.addArrangedSubview(summaryRow(strings.labelRate, viewModel.rateText))
        card.contentStack.addArrangedSubview(summaryRow(strings.labelHold, viewModel.holdText))

        let sandbox = UILabel(text: strings.activateSandboxNote,
                              font: AppFont.body(13), color: AppColor.ink)
        sandbox.backgroundColor = AppColor.sand
        sandbox.applyInkOutline(cornerRadius: AppMetrics.radiusChip, clip: true)
        sandbox.numberOfLines = 0

        let stack = UIStackView(axis: .vertical, spacing: AppMetrics.space4,
                                arrangedSubviews: [heading, card, sandbox])

        if let insufficientFunds {
            let warn = UILabel(text: "  \(insufficientFunds)  ", font: AppFont.body(13, weight: .semibold),
                               color: AppColor.cream)
            warn.backgroundColor = AppColor.rust
            warn.applyInkOutline(cornerRadius: AppMetrics.radiusChip, clip: true)
            warn.numberOfLines = 0
            let addFunds = PillButton(title: viewModel.strings.value.walletTitle, style: .primary)
            addFunds.setTitle("Add funds", for: .normal)
            addFunds.onTap = { [weak viewModel] in viewModel?.addFunds() }
            [warn, addFunds].forEach { stack.addArrangedSubview($0) }
        } else {
            let cta = PillButton(title: strings.activateConfirmButton, style: .dark)
            cta.isEnabled = !processing
            cta.alpha = processing ? 0.6 : 1
            cta.onTap = { [weak viewModel] in viewModel?.confirmPayment() }
            stack.addArrangedSubview(cta)
        }
        return stack
    }

    private func summaryRow(_ caption: String, _ value: String) -> UIView {
        let c = UILabel(text: caption, font: AppFont.body(15), color: AppColor.stone)
        let v = UILabel(text: value, font: AppFont.slab(16, weight: .bold), alignment: .right)
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return UIStackView(axis: .horizontal, arrangedSubviews: [c, v])
    }

    @objc private func close() { viewModel.cancel() }
}

/// Tappable port option in the "select port" step (radio dot on the trailing edge).
private final class SelectablePortRow: OutlinedCardView {
    var onTap: (() -> Void)?

    init(port: ChargingPort, isSelected: Bool) {
        super.init(fill: isSelected ? AppColor.gold : AppColor.parchment,
                   cornerRadius: 22, contentInset: AppMetrics.space4, shadowOffsetY: 0)
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = AppMetrics.space3

        let title = UILabel(text: "\(port.connector.displayName) · \(port.powerText)",
                            font: AppFont.slab(18, weight: .bold))
        let note = UILabel(text: port.note, font: AppFont.body(13), color: AppColor.stone)
        note.isHidden = (port.note ?? "").isEmpty
        let text = UIStackView(axis: .vertical, spacing: 2, arrangedSubviews: [title, note])
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let dot = UIView()
        dot.applyInkOutline(cornerRadius: 11, clip: true)
        dot.backgroundColor = isSelected ? AppColor.orange : .clear
        dot.widthAnchor.constraint(equalToConstant: 22).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 22).isActive = true

        contentStack.addArrangedSubview(text)
        contentStack.addArrangedSubview(dot)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }
}

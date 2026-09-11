//
//  ActiveSessionViewController.swift
//  ChargePath
//
//  The live charging screen. While a session runs it shows elapsed time,
//  simulated energy and running cost with a Stop button; once stopped it
//  swaps to a receipt (energy, duration, total charged).
//

import UIKit
import RxSwift
import RxRelay
import RxCocoa

final class ActiveSessionViewController: UIViewController {

    private let viewModel: ActiveSessionViewModel
    private let disposeBag = DisposeBag()

    private let container = UIStackView(axis: .vertical, spacing: AppMetrics.space5)
    private let disc = UIView()
    private let discBolt = UIImageView(image: UIImage(systemName: "bolt.fill"))
    private let headline = UILabel(font: AppFont.display(26), alignment: .center)
    private let stationLabel = UILabel(font: AppFont.body(15), color: AppColor.stone, alignment: .center)
    private let rowsStack = UIStackView(axis: .vertical, spacing: AppMetrics.space2)
    private lazy var actionButton = PillButton(title: "", style: .dark)

    init(viewModel: ActiveSessionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true   // can't swipe away mid-session
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.cream
        buildLayout()
        bind()
        pulseDisc()
    }

    // MARK: Layout

    private func buildLayout() {
        let badge = UILabel(text: "  \(viewModel.strings.value.testModeBadge)  ",
                            font: AppFont.body(11, weight: .bold),
                            color: AppColor.gold, alignment: .center)
        badge.backgroundColor = AppColor.ink
        badge.applyInkOutline(cornerRadius: 12, clip: true)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        let badgeRow = UIStackView(axis: .horizontal, arrangedSubviews: [UIView(), badge, UIView()])

        disc.backgroundColor = AppColor.gold
        disc.applyInkOutline(cornerRadius: 60, width: 3, clip: true)
        disc.widthAnchor.constraint(equalToConstant: 120).isActive = true
        disc.heightAnchor.constraint(equalToConstant: 120).isActive = true
        discBolt.tintColor = AppColor.ink
        discBolt.contentMode = .scaleAspectFit
        disc.addAutoLayoutSubview(discBolt)
        NSLayoutConstraint.activate([
            discBolt.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            discBolt.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
            discBolt.widthAnchor.constraint(equalToConstant: 54),
            discBolt.heightAnchor.constraint(equalToConstant: 54)
        ])
        let discRow = UIStackView(axis: .horizontal, alignment: .center,
                                  arrangedSubviews: [UIView(), disc, UIView()])

        actionButton.onTap = { [weak self] in
            guard let self else { return }
            self.viewModel.receipt.value == nil ? self.viewModel.stopTapped() : self.viewModel.done()
        }

        [badgeRow, discRow, headline, stationLabel, rowsStack, actionButton]
            .forEach { container.addArrangedSubview($0) }
        container.setCustomSpacing(AppMetrics.space6, after: rowsStack)

        view.addAutoLayoutSubview(container)
        NSLayoutConstraint.activate([
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space5),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space5)
        ])
    }

    private func metricRow(_ caption: String, _ relay: BehaviorRelay<String>) -> UIView {
        let c = UILabel(text: caption, font: AppFont.body(15), color: AppColor.stone)
        let v = UILabel(font: AppFont.slab(20, weight: .bold), alignment: .right)
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        relay.bind(to: v.rx.text).disposed(by: disposeBag)
        let card = OutlinedCardView(fill: AppColor.parchment, cornerRadius: AppMetrics.radiusChip,
                                    contentInset: AppMetrics.space4, shadowOffsetY: 0)
        card.contentStack.axis = .horizontal
        card.contentStack.alignment = .center
        [c, v].forEach { card.contentStack.addArrangedSubview($0) }
        return card
    }

    private func receiptRow(_ caption: String, _ value: String) -> UIView {
        let c = UILabel(text: caption, font: AppFont.body(15), color: AppColor.stone)
        let v = UILabel(text: value, font: AppFont.slab(17, weight: .bold), alignment: .right)
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return UIStackView(axis: .horizontal, arrangedSubviews: [c, v])
    }

    // MARK: Bindings

    private func bind() {
        viewModel.stationLine.bind(to: stationLabel.rx.text).disposed(by: disposeBag)

        viewModel.receipt
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] receipt in
                self?.renderState(receipt: receipt)
            })
            .disposed(by: disposeBag)

        viewModel.isStopping
            .subscribe(onNext: { [weak self] stopping in
                self?.actionButton.isEnabled = !stopping
                self?.actionButton.alpha = stopping ? 0.6 : 1
            })
            .disposed(by: disposeBag)
    }

    private func renderState(receipt: ChargingSessionReceipt?) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let s = viewModel.strings.value

        if let receipt {
            disc.layer.removeAllAnimations()
            disc.transform = .identity
            headline.text = s.sessionDoneHeading
            stationLabel.text = "\(receipt.stationName) · \(receipt.portLabel)"
            rowsStack.addArrangedSubview(receiptRow(s.sessionEnergy,
                String(format: "%.1f kWh", receipt.energyKWh)))
            rowsStack.addArrangedSubview(receiptRow(s.sessionDuration,
                "\(receipt.durationMinutes) min"))
            rowsStack.addArrangedSubview(receiptRow(s.sessionRate,
                String(format: "$%.2f / kWh", receipt.ratePerKWh)))
            rowsStack.addArrangedSubview(receiptRow(s.sessionTotal,
                String(format: "$%.2f", receipt.totalCharged)))
            actionButton.setTitle(s.activateBackToMap, for: .normal)
            actionButton.apply(.primary)
        } else {
            headline.text = s.sessionChargingHeading
            rowsStack.addArrangedSubview(metricRow(s.sessionElapsed, viewModel.elapsedText))
            rowsStack.addArrangedSubview(metricRow(s.sessionEnergy, viewModel.energyText))
            rowsStack.addArrangedSubview(metricRow(s.sessionCost, viewModel.costText))
            rowsStack.addArrangedSubview(metricRow(s.sessionPower, viewModel.powerText))
            actionButton.setTitle(s.sessionStop, for: .normal)
            actionButton.apply(.dark)
        }
    }

    private func pulseDisc() {
        UIView.animate(withDuration: 1.1, delay: 0,
                       options: [.repeat, .autoreverse, .allowUserInteraction]) {
            self.disc.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        }
    }
}

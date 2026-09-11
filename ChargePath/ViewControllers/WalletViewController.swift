//
//  WalletViewController.swift
//  ChargePath
//
//  Settings › Wallet. Dark balance card, top-up amount chips, "add funds"
//  (mock sandbox card) and payment history. Bound to WalletViewModel.
//

import UIKit
import RxSwift
import RxRelay
import RxCocoa

final class WalletViewController: UIViewController {

    private let viewModel: WalletViewModel
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let balanceLabel = UILabel(font: AppFont.display(40), color: AppColor.cream)
    private let topUpRow = UIStackView(axis: .horizontal, spacing: AppMetrics.space2)
    private lazy var addFundsButton = PillButton(title: "", style: .primary)
    private let historyStack = UIStackView(axis: .vertical, spacing: AppMetrics.space2)

    init(viewModel: WalletViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.cream
        title = viewModel.strings.value.walletTitle
        buildLayout()
        bind()
    }

    private func buildLayout() {
        let s = viewModel.strings.value

        // Dark balance card.
        let balanceCaption = UILabel(text: s.walletAvailableBalance.uppercased(),
                                     font: AppFont.slab(12, weight: .bold),
                                     color: AppColor.cream.withAlphaComponent(0.7))
        let tricolor = tricolorBar(width: 132)
        let balanceCard = OutlinedCardView(fill: AppColor.ink, cornerRadius: 28,
                                           contentInset: AppMetrics.space5, shadowOffsetY: 9)
        balanceCard.contentStack.spacing = AppMetrics.space3
        [balanceCaption, balanceLabel, tricolor].forEach { balanceCard.contentStack.addArrangedSubview($0) }

        // Top-up chips.
        for amount in viewModel.topUpAmounts {
            let chip = ChipView(text: "$\(Int(amount))")
            chip.onTap = { [weak viewModel] in viewModel?.selectTopUp(amount) }
            chip.accessibilityValue = "\(Int(amount))"
            topUpRow.addArrangedSubview(chip)
        }
        topUpRow.addArrangedSubview(UIView())

        addFundsButton.onTap = { [weak viewModel] in viewModel?.addFunds() }

        let stack = UIStackView(axis: .vertical, spacing: AppMetrics.space4, arrangedSubviews: [
            balanceCard,
            topUpRow,
            addFundsButton,
            sectionLabel(s.walletPaymentHistory),
            historyStack
        ])
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
        viewModel.balanceText.bind(to: balanceLabel.rx.text).disposed(by: disposeBag)
        viewModel.addFundsLabel
            .subscribe(onNext: { [weak self] in self?.addFundsButton.setTitle($0, for: .normal) })
            .disposed(by: disposeBag)

        viewModel.selectedTopUp
            .subscribe(onNext: { [weak self] amount in
                for case let chip as ChipView in self?.topUpRow.arrangedSubviews ?? [] {
                    chip.isOn = chip.accessibilityValue == "\(Int(amount))"
                }
            })
            .disposed(by: disposeBag)

        viewModel.transactions
            .subscribe(onNext: { [weak self] transactions in self?.renderHistory(transactions) })
            .disposed(by: disposeBag)
    }

    private func renderHistory(_ transactions: [WalletTransaction]) {
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tx in transactions {
            let dot = UIView()
            dot.backgroundColor = tx.kind == .credit ? AppColor.available : AppColor.orange
            dot.layer.cornerRadius = 6
            dot.widthAnchor.constraint(equalToConstant: 12).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 12).isActive = true

            let title = UILabel(text: tx.title, font: AppFont.slab(16, weight: .bold))
            let sub = UILabel(text: tx.subtitle, font: AppFont.body(13), color: AppColor.stone)
            let text = UIStackView(axis: .vertical, spacing: 2, arrangedSubviews: [title, sub])
            text.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let amount = UILabel(text: tx.amountText, font: AppFont.slab(16, weight: .bold),
                                 color: tx.kind == .credit ? AppColor.available : AppColor.ink,
                                 alignment: .right)

            let row = OutlinedCardView(cornerRadius: 20, contentInset: AppMetrics.space4, shadowOffsetY: 0)
            row.contentStack.axis = .horizontal
            row.contentStack.alignment = .center
            row.contentStack.spacing = AppMetrics.space3
            [dot, text, amount].forEach { row.contentStack.addArrangedSubview($0) }
            historyStack.addArrangedSubview(row)
        }
    }

    private func sectionLabel(_ text: String) -> UILabel {
        UILabel(text: text.uppercased(), font: AppFont.slab(13, weight: .bold), color: AppColor.stone)
    }

    private func tricolorBar(width: CGFloat) -> UIView {
        let bar = UIStackView(axis: .horizontal, distribution: .fillEqually)
        [AppColor.gold, AppColor.orange, AppColor.rust].forEach {
            let seg = UIView(); seg.backgroundColor = $0
            bar.addArrangedSubview(seg)
        }
        bar.layer.cornerRadius = 3
        bar.layer.masksToBounds = true
        bar.widthAnchor.constraint(equalToConstant: width).isActive = true
        bar.heightAnchor.constraint(equalToConstant: 6).isActive = true
        return bar
    }
}

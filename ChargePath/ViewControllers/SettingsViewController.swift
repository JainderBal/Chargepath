//
//  SettingsViewController.swift
//  ChargePath
//
//  Screen 5 — Settings. Vehicle profile, EN/FR language toggle, Wallet
//  summary, Membership row (→ Paywall), app info, and the bookmarked-stations
//  list. All values come from RxSwift bindings on SettingsViewModel.
//

import UIKit
import RxSwift
import RxRelay
import RxCocoa

final class SettingsViewController: UIViewController {

    private let viewModel: SettingsViewModel
    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let stripes = StripeBackgroundView()

    private let vehicleValueLabel = UILabel(font: AppFont.slab(19, weight: .bold))
    private lazy var languageToggle = MorphingToggleView(titles: [
        AppLanguage.en.shortLabel, AppLanguage.fr.shortLabel
    ])
    private let walletValueLabel = UILabel(font: AppFont.slab(18, weight: .bold), alignment: .right)
    private let appInfoLabel = UILabel(font: AppFont.body(14), color: AppColor.stone, alignment: .right)
    private let bookmarksStack = UIStackView(axis: .vertical, spacing: AppMetrics.space2)

    // Static copy re-applied by `applyStrings(_:)` whenever the language
    // changes — everything else on this screen is already a live Rx binding.
    private let headingLabel = UILabel(font: AppFont.display(30))
    private let vehicleCaptionLabel = UILabel(font: AppFont.body(13), color: AppColor.stone)
    private let langLabel = UILabel(font: AppFont.slab(17, weight: .semibold))
    private let walletTitleLabel = UILabel(font: AppFont.slab(17, weight: .semibold))
    private let walletSubLabel = UILabel(font: AppFont.body(13), color: AppColor.stone)
    private let aboutLabel = UILabel(font: AppFont.slab(17, weight: .semibold))
    private let bookmarksSectionLabel = UILabel(font: AppFont.slab(13, weight: .bold), color: AppColor.stone)

    init(viewModel: SettingsViewModel) {
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
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: Layout

    private func buildLayout() {
        stripes.angleDegrees = 18   // Settings tilts the other way in the mockup
        view.addAutoLayoutSubview(stripes)
        NSLayoutConstraint.activate([
            stripes.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stripes.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stripes.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stripes.heightAnchor.constraint(equalToConstant: 240)
        ])

        view.addAutoLayoutSubview(scrollView)
        scrollView.pinEdges(to: view)

        let stack = UIStackView(axis: .vertical, spacing: AppMetrics.space4, arrangedSubviews: [
            headingLabel,
            makeVehicleRow(),
            makeOptionsCard(),
            bookmarksSectionLabel,
            bookmarksStack
        ])
        scrollView.addAutoLayoutSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppMetrics.space5),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppMetrics.space8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppMetrics.space5),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppMetrics.space5)
        ])
    }

    private func makeVehicleRow() -> UIView {
        let icon = iconTile("bolt.fill", background: AppColor.sky)
        let text = UIStackView(axis: .vertical, spacing: 2, arrangedSubviews: [vehicleCaptionLabel, vehicleValueLabel])
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let chevron = chevronView()

        let card = OutlinedCardView()
        card.contentStack.axis = .horizontal
        card.contentStack.alignment = .center
        card.contentStack.spacing = AppMetrics.space3
        [icon, text, chevron].forEach { card.contentStack.addArrangedSubview($0) }
        addTap(to: card) { [weak viewModel] in viewModel?.openVehicle() }
        return card
    }

    private func makeOptionsCard() -> UIView {
        let card = OutlinedCardView(contentInset: 0)
        card.contentStack.spacing = 0

        // Language
        langLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        languageToggle.widthAnchor.constraint(equalToConstant: 96).isActive = true
        languageToggle.onSelect = { [weak viewModel] index in
            viewModel?.setLanguage(index == 0 ? .en : .fr)
        }
        card.contentStack.addArrangedSubview(paddedRow([langLabel, languageToggle]))
        card.contentStack.addArrangedSubview(hairline())

        // Wallet
        let walletText = UIStackView(axis: .vertical, spacing: 2, arrangedSubviews: [walletTitleLabel, walletSubLabel])
        walletText.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let walletRow = paddedRow([walletText, walletValueLabel, chevronView()])
        addTap(to: walletRow) { [weak viewModel] in viewModel?.openWallet() }
        card.contentStack.addArrangedSubview(walletRow)
        card.contentStack.addArrangedSubview(hairline())

        // App info
        aboutLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        appInfoLabel.text = viewModel.appVersionText
        card.contentStack.addArrangedSubview(paddedRow([aboutLabel, appInfoLabel]))

        return card
    }

    // MARK: Bindings

    private func bind() {
        viewModel.strings
            .subscribe(onNext: { [weak self] strings in self?.applyStrings(strings) })
            .disposed(by: disposeBag)

        viewModel.vehicleName.bind(to: vehicleValueLabel.rx.text).disposed(by: disposeBag)
        viewModel.walletBalanceText.bind(to: walletValueLabel.rx.text).disposed(by: disposeBag)

        viewModel.language
            .subscribe(onNext: { [weak self] language in
                self?.languageToggle.setSelectedIndex(language == .en ? 0 : 1, animated: false)
            })
            .disposed(by: disposeBag)

        viewModel.bookmarkedStations
            .subscribe(onNext: { [weak self] stations in self?.renderBookmarks(stations) })
            .disposed(by: disposeBag)
    }

    /// Re-applies every static string on the screen — called once at launch
    /// and again on every language switch, so this is the one screen that
    /// used to freeze at whatever language it first rendered in.
    private func applyStrings(_ strings: Strings) {
        headingLabel.text = strings.settingsTitle
        vehicleCaptionLabel.text = strings.settingsVehicleProfile
        langLabel.text = strings.settingsLanguage
        walletTitleLabel.text = strings.walletTitle
        walletSubLabel.text = strings.walletSubtitle
        aboutLabel.text = strings.settingsAppInfo
        bookmarksSectionLabel.text = strings.settingsBookmarkedStations.uppercased()
        renderBookmarks(viewModel.bookmarkedStations.value)
    }

    private func renderBookmarks(_ stations: [Station]) {
        bookmarksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !stations.isEmpty else {
            let empty = UILabel(text: viewModel.strings.value.settingsEmptyBookmarksBody,
                                font: AppFont.body(13), color: AppColor.stone)
            empty.numberOfLines = 0
            bookmarksStack.addArrangedSubview(empty)
            return
        }
        for station in stations {
            let star = UIImageView(image: UIImage(systemName: "star.fill"))
            star.tintColor = AppColor.gold
            star.setContentHuggingPriority(.required, for: .horizontal)
            let name = UILabel(text: station.name, font: AppFont.slab(16, weight: .semibold))
            name.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let row = OutlinedCardView(fill: AppColor.sand, cornerRadius: 20,
                                       contentInset: AppMetrics.space3, shadowOffsetY: 0)
            row.contentStack.axis = .horizontal
            row.contentStack.alignment = .center
            row.contentStack.spacing = AppMetrics.space3
            [star, name].forEach { row.contentStack.addArrangedSubview($0) }
            addTap(to: row) { [weak viewModel] in viewModel?.selectBookmarkedStation(station) }
            bookmarksStack.addArrangedSubview(row)
        }
    }

    // MARK: Small builders

    private func paddedRow(_ views: [UIView]) -> UIView {
        let row = UIStackView(axis: .horizontal, spacing: AppMetrics.space3,
                              alignment: .center, arrangedSubviews: views)
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: AppMetrics.space4, left: AppMetrics.space4,
                                         bottom: AppMetrics.space4, right: AppMetrics.space4)
        return row
    }

    private func hairline() -> UIView {
        let v = UIView(); v.backgroundColor = AppColor.sand
        v.heightAnchor.constraint(equalToConstant: 2).isActive = true
        return v
    }

    private func iconTile(_ systemName: String, background: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = background
        container.applyInkOutline(cornerRadius: 14, clip: true)
        container.widthAnchor.constraint(equalToConstant: 46).isActive = true
        container.heightAnchor.constraint(equalToConstant: 46).isActive = true
        let image = UIImageView(image: UIImage(systemName: systemName))
        image.tintColor = AppColor.cream
        container.addAutoLayoutSubview(image)
        image.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
        image.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
        return container
    }

    private func chevronView() -> UIView {
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColor.stone
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        return chevron
    }

    private func addTap(to view: UIView, _ action: @escaping () -> Void) {
        view.isUserInteractionEnabled = true
        let recognizer = ClosureTapGestureRecognizer(action: action)
        view.addGestureRecognizer(recognizer)
    }
}

/// UITapGestureRecognizer that keeps its own closure — avoids per-screen
/// @objc selector plumbing for the many tappable rows.
final class ClosureTapGestureRecognizer: UITapGestureRecognizer {
    private let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(fire))
    }
    @objc private func fire() { action() }
}

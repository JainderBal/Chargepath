//
//  MorphingToggleView.swift
//  ChargePath
//
//  The two-option segmented toggle from the mockup (All / Bookmarked on the
//  Map, EN / FR in Settings). An ink pill slides behind the selected label
//  with a springy transition.
//

import UIKit

final class MorphingToggleView: UIControl {

    /// Fires with the newly-selected index (0 or 1).
    var onSelect: ((Int) -> Void)?

    private(set) var selectedIndex: Int = 0

    private let indicator = UIView()
    private let stack = UIStackView(axis: .horizontal, distribution: .fillEqually)
    private var labels: [UILabel] = []

    init(titles: [String]) {
        super.init(frame: .zero)
        precondition(titles.count == 2, "MorphingToggleView supports exactly two options")

        backgroundColor = AppColor.sand
        applyInkBorder()

        indicator.backgroundColor = AppColor.ink
        addAutoLayoutSubview(indicator)

        for (i, title) in titles.enumerated() {
            let label = UILabel(text: title, font: AppFont.body(13, weight: .bold),
                                color: AppColor.stone, alignment: .center)
            label.isUserInteractionEnabled = true
            label.tag = i
            label.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            )
            labels.append(label)
            stack.addArrangedSubview(label)
        }
        addAutoLayoutSubview(stack)
        stack.pinEdges(to: self, inset: 3)

        NSLayoutConstraint.activate([
            // Explicit height — no intrinsic size, would collapse otherwise.
            heightAnchor.constraint(equalToConstant: 40),
            indicator.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            indicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            indicator.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5, constant: -3),
            indicatorLeading
        ])
        updateLabelColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private lazy var indicatorLeading: NSLayoutConstraint =
        indicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3)

    /// Re-applies the two labels' text — for a toggle whose options are
    /// localized copy (e.g. Map's All/Bookmarked segment) rather than fixed
    /// codes (EN/FR), call this again whenever the app language changes.
    func setTitles(_ titles: [String]) {
        precondition(titles.count == 2, "MorphingToggleView supports exactly two options")
        for (label, title) in zip(labels, titles) {
            label.text = title
        }
    }

    func setSelectedIndex(_ index: Int, animated: Bool) {
        selectedIndex = index
        let offset = index == 0 ? 3 : bounds.width / 2
        indicatorLeading.constant = offset
        let work = {
            self.layoutIfNeeded()
            self.updateLabelColors()
        }
        guard animated else { work(); return }
        UIView.animate(withDuration: 0.5, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3,
                       options: [.allowUserInteraction], animations: work)
    }

    private func updateLabelColors() {
        for (i, label) in labels.enumerated() {
            label.textColor = i == selectedIndex ? AppColor.cream : AppColor.stone
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundCornersAsPill()
        indicator.layer.cornerRadius = max(0, indicator.bounds.height / 2)
        // Keep the indicator aligned after size changes.
        indicatorLeading.constant = selectedIndex == 0 ? 3 : bounds.width / 2
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag, index != selectedIndex else { return }
        setSelectedIndex(index, animated: true)
        onSelect?(index)
    }
}

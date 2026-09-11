//
//  ChipView.swift
//  ChargePath
//
//  Small rounded pill used for connector badges, filter options and port
//  status. `isOn` toggles the gold "selected" treatment with the mockup's
//  springy transform.
//

import UIKit

final class ChipView: UIControl {

    var onTap: (() -> Void)?

    private let label = UILabel(font: AppFont.body(12, weight: .bold),
                                color: AppColor.ink,
                                alignment: .center)

    var text: String? {
        get { label.text }
        set { label.text = newValue }
    }

    var isOn: Bool = false {
        didSet { updateAppearance(animated: true) }
    }

    /// When set, overrides the default on/off fill (used for status colours).
    var fixedFill: UIColor? {
        didSet { updateAppearance(animated: false) }
    }
    var fixedTextColor: UIColor? {
        didSet { updateAppearance(animated: false) }
    }

    init(text: String? = nil) {
        super.init(frame: .zero)
        self.label.text = text
        applyInkBorder()   // corner radius clamped to a pill in layoutSubviews

        addAutoLayoutSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        updateAppearance(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundCornersAsPill()
    }

    private func updateAppearance(animated: Bool) {
        let fill: UIColor
        let textColor: UIColor
        if let fixedFill {
            fill = fixedFill
            textColor = fixedTextColor ?? AppColor.cream
        } else {
            fill = isOn ? AppColor.gold : AppColor.parchment
            textColor = AppColor.ink
        }

        let work = {
            self.backgroundColor = fill
            self.label.textColor = textColor
            self.transform = self.isOn && self.fixedFill == nil
                ? CGAffineTransform(scaleX: 1.05, y: 1.05)
                : .identity
            self.layer.shadowOpacity = (self.isOn && self.fixedFill == nil) ? 1 : 0
            self.layer.shadowColor = AppColor.ink.cgColor
            self.layer.shadowRadius = 0
            self.layer.shadowOffset = CGSize(width: 0, height: 3)
        }
        guard animated else { work(); return }
        UIView.animate(withDuration: 0.35,
                       delay: 0,
                       usingSpringWithDamping: 0.55,
                       initialSpringVelocity: 0.4,
                       options: [.allowUserInteraction],
                       animations: work)
    }

    @objc private func handleTap() { onTap?() }
}

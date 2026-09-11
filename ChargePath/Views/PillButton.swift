//
//  PillButton.swift
//  ChargePath
//
//  The mockup's primary call-to-action: a fully-rounded slab-serif button with
//  an ink border and a hard offset shadow. Style variants cover the orange
//  CTA, the dark "confirm" button and the disabled state.
//

import UIKit

final class PillButton: UIButton {

    enum Style {
        case primary        // orange fill, cream text
        case dark           // ink fill, cream text
        case gold           // gold fill, ink text
        case disabled       // sand fill, muted text, no shadow
    }

    var onTap: (() -> Void)?

    private var style: Style = .primary

    init(title: String, style: Style = .primary) {
        super.init(frame: .zero)
        titleLabel?.font = AppFont.slab(19, weight: .bold)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.8
        // Buttons are always full-width in a vertical stack, so vertical
        // breathing room is a height constraint (contentEdgeInsets is
        // deprecated and only honoured with UIButton.Configuration).
        heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        layer.borderWidth = AppMetrics.hairline   // radius clamped in layoutSubviews
        setTitle(title, for: .normal)
        apply(style)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundCornersAsPill()
    }

    func apply(_ style: Style) {
        self.style = style
        layer.borderColor = AppColor.ink.cgColor
        switch style {
        case .primary:
            backgroundColor = AppColor.orange
            setTitleColor(AppColor.cream, for: .normal)
            applyHardShadow(offsetY: 7, opacity: 1)
        case .dark:
            backgroundColor = AppColor.ink
            setTitleColor(AppColor.cream, for: .normal)
            applyHardShadow(offsetY: 7, opacity: 0.35)
        case .gold:
            backgroundColor = AppColor.gold
            setTitleColor(AppColor.ink, for: .normal)
            applyHardShadow(offsetY: 7, opacity: 1)
        case .disabled:
            backgroundColor = AppColor.sand
            setTitleColor(AppColor.stone, for: .normal)
            layer.shadowOpacity = 0
        }
    }

    func setEnabledStyle(_ enabled: Bool, enabledStyle: Style = .primary) {
        isEnabled = enabled
        apply(enabled ? enabledStyle : .disabled)
    }

    @objc private func handleTap() { onTap?() }
}

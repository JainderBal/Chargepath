//
//  UIKitHelpers.swift
//  ChargePath
//
//  Small shared UIKit conveniences used across the programmatic views.
//

import UIKit

extension UIView {
    /// Add `subview` with autolayout enabled.
    func addAutoLayoutSubview(_ subview: UIView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
    }

    /// Pin edges to a target (default: superview) with an inset.
    func pinEdges(to target: UIView? = nil, inset: CGFloat = 0) {
        guard let target = target ?? superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: target.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: target.trailingAnchor, constant: -inset),
            topAnchor.constraint(equalTo: target.topAnchor, constant: inset),
            bottomAnchor.constraint(equalTo: target.bottomAnchor, constant: -inset)
        ])
    }

    /// The mockup's signature "hard" offset shadow (no blur).
    func applyHardShadow(offsetY: CGFloat = 6, color: UIColor = AppColor.ink, opacity: Float = 0.18) {
        layer.shadowColor = color.cgColor
        layer.shadowOffset = CGSize(width: 0, height: offsetY)
        layer.shadowRadius = 0
        layer.shadowOpacity = opacity
        layer.masksToBounds = false
    }

    /// The "hand-drawn" ink outline. Use a real, in-bounds `cornerRadius`
    /// here — an out-of-bounds value (e.g. a 999 "pill" constant) makes the
    /// layer fill *and* border stop rendering on current iOS. For pills call
    /// `applyInkBorder()` and clamp the radius from `layoutSubviews` with
    /// `roundCornersAsPill()`.
    /// `clip: true` for small filled tiles/badges/discs — without it the fill
    /// can render to square corners even though the border follows the radius.
    /// Leave `clip: false` for anything that also casts a hard shadow.
    func applyInkOutline(cornerRadius: CGFloat, width: CGFloat = AppMetrics.hairline, clip: Bool = false) {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        applyInkBorder(width: width)
        if clip { clipsToBounds = true }
    }

    /// Just the ink border — no corner radius change.
    func applyInkBorder(width: CGFloat = AppMetrics.hairline) {
        layer.borderWidth = width
        layer.borderColor = AppColor.ink.cgColor
    }

    /// Call from `layoutSubviews` so a view stays a true pill as it resizes.
    func roundCornersAsPill() {
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}

extension UIStackView {
    convenience init(axis: NSLayoutConstraint.Axis,
                     spacing: CGFloat = 0,
                     alignment: Alignment = .fill,
                     distribution: Distribution = .fill,
                     arrangedSubviews: [UIView] = []) {
        self.init(arrangedSubviews: arrangedSubviews)
        self.axis = axis
        self.spacing = spacing
        self.alignment = alignment
        self.distribution = distribution
    }
}

extension UILabel {
    convenience init(text: String? = nil,
                     font: UIFont,
                     color: UIColor = AppColor.ink,
                     alignment: NSTextAlignment = .natural,
                     numberOfLines: Int = 0) {
        self.init()
        self.text = text
        self.font = font
        self.textColor = color
        self.textAlignment = alignment
        self.numberOfLines = numberOfLines
        self.adjustsFontForContentSizeCategory = true   // Dynamic Type
    }
}

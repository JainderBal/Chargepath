//
//  StripeBackgroundView.swift
//  ChargePath
//
//  The retro diagonal tricolor stripe motif that sits behind the Route
//  Planner and Settings screens in the mockup (gold / orange / rust / sky /
//  green bars, rotated ~18°). Purely decorative.
//

import UIKit

final class StripeBackgroundView: UIView {

    /// Rotation direction differs per tab in the mockup (Settings tilts the
    /// other way); expose it so screens can set their own angle.
    var angleDegrees: CGFloat = -18 {
        didSet { setNeedsLayout() }
    }

    private let bandColors: [UIColor] = [
        AppColor.gold, AppColor.orange, AppColor.rust, AppColor.sky, AppColor.available
    ]
    private let bandStack = UIStackView(axis: .vertical, spacing: 8)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = true

        for color in bandColors {
            let bar = UIView()
            bar.backgroundColor = color
            bar.heightAnchor.constraint(equalToConstant: 17).isActive = true
            bandStack.addArrangedSubview(bar)
        }
        addAutoLayoutSubview(bandStack)
        NSLayoutConstraint.activate([
            bandStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            bandStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -70),
            bandStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 70)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        bandStack.transform = CGAffineTransform(rotationAngle: angleDegrees * .pi / 180)
    }
}

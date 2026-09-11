//
//  RouteStopRowView.swift
//  ChargePath
//
//  One charging stop in the Route Planner results list: a gold numbered
//  circle, the station name + detail line, and a minutes badge.
//

import UIKit

final class RouteStopRowView: OutlinedCardView {

    var onTap: (() -> Void)?

    init(stop: ChargingStop) {
        super.init(fill: AppColor.parchment, cornerRadius: 22,
                   contentInset: AppMetrics.space4, shadowOffsetY: 7)
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = AppMetrics.space3

        let number = UILabel(text: "\(stop.index)", font: AppFont.slab(16, weight: .bold),
                             color: AppColor.ink, alignment: .center)
        number.backgroundColor = AppColor.gold
        number.applyInkOutline(cornerRadius: 17)
        number.layer.masksToBounds = true
        number.widthAnchor.constraint(equalToConstant: 34).isActive = true
        number.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let name = UILabel(text: stop.station.name, font: AppFont.slab(18, weight: .bold))
        let detail = UILabel(text: stop.detailText, font: AppFont.body(13), color: AppColor.stone)
        let text = UIStackView(axis: .vertical, spacing: 2, arrangedSubviews: [name, detail])
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let badge = ChipView(text: "\(stop.estimatedChargeMinutes) min")
        badge.isUserInteractionEnabled = false
        badge.fixedFill = AppColor.sky
        badge.fixedTextColor = AppColor.cream

        [number, text, badge].forEach { contentStack.addArrangedSubview($0) }
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }
}

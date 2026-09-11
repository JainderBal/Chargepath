//
//  PortRowView.swift
//  ChargePath
//
//  One row in the Station Detail / Activate Charging port list: bay label
//  chip, "connector · kW", note, and a status badge. During the "checking"
//  phase the status reads "···" and the row dims (mockup behaviour).
//

import UIKit

final class PortRowView: OutlinedCardView {

    init(port: ChargingPort, checking: Bool) {
        super.init(fill: AppColor.parchment,
                   cornerRadius: AppMetrics.radiusChip,
                   contentInset: AppMetrics.space3,
                   shadowOffsetY: 0)
        contentStack.axis = .horizontal
        contentStack.spacing = AppMetrics.space3
        contentStack.alignment = .center

        let bay = UILabel(text: port.label, font: AppFont.slab(14, weight: .bold),
                          color: AppColor.ink, alignment: .center)
        bay.backgroundColor = AppColor.sand
        bay.applyInkOutline(cornerRadius: 12, clip: true)
        bay.widthAnchor.constraint(equalToConstant: 34).isActive = true
        bay.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let title = UILabel(text: "\(port.connector.displayName) · \(port.powerText)",
                            font: AppFont.slab(16, weight: .bold))
        let note = UILabel(text: port.note, font: AppFont.body(13), color: AppColor.stone)
        note.isHidden = (port.note ?? "").isEmpty
        let textBlock = UIStackView(axis: .vertical, spacing: 2,
                                    arrangedSubviews: [title, note])
        textBlock.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let badge = ChipView(text: checking ? "···" : port.status.displayName)
        badge.isUserInteractionEnabled = false
        badge.fixedFill = checking ? AppColor.sand : AppColor.status(port.status)
        badge.fixedTextColor = checking ? AppColor.stone : AppColor.statusForeground(port.status)
        // Uniform width so Available / In use / Offline / ··· all line up.
        badge.widthAnchor.constraint(equalToConstant: 92).isActive = true
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentStack.addArrangedSubview(bay)
        contentStack.addArrangedSubview(textBlock)
        contentStack.addArrangedSubview(badge)

        alpha = checking ? 0.55 : 1
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

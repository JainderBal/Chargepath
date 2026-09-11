//
//  OutlinedCardView.swift
//  ChargePath
//
//  Parchment surface with an ink outline and a hard offset shadow — the base
//  container for cards, list rows and sheets throughout the mockup.
//

import UIKit

class OutlinedCardView: UIView {

    /// Content is laid inside this inset stack; callers add arranged subviews.
    let contentStack = UIStackView(axis: .vertical, spacing: AppMetrics.space2)

    init(fill: UIColor = AppColor.parchment,
         cornerRadius: CGFloat = AppMetrics.radiusCard,
         contentInset: CGFloat = AppMetrics.space4,
         shadowOffsetY: CGFloat = 8) {
        super.init(frame: .zero)
        backgroundColor = fill
        applyInkOutline(cornerRadius: cornerRadius)
        applyHardShadow(offsetY: shadowOffsetY, opacity: 0.2)

        addAutoLayoutSubview(contentStack)
        contentStack.pinEdges(to: self, inset: contentInset)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

//
//  SearchFieldView.swift
//  ChargePath
//
//  The rounded search field from the top of the Map screen: magnifier icon +
//  text field inside a cream pill with an ink outline and hard shadow.
//

import UIKit

final class SearchFieldView: UIView {

    let textField = UITextField()

    init(placeholder: String) {
        super.init(frame: .zero)
        backgroundColor = AppColor.parchment
        applyInkBorder()
        applyHardShadow(offsetY: 6, opacity: 0.18)

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = AppColor.stone
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        textField.placeholder = placeholder
        textField.font = AppFont.body(16)
        textField.textColor = AppColor.ink
        textField.returnKeyType = .search
        textField.clearButtonMode = .whileEditing
        textField.autocorrectionType = .no

        let stack = UIStackView(axis: .horizontal, spacing: 10,
                                alignment: .center,
                                arrangedSubviews: [icon, textField])
        addAutoLayoutSubview(stack)
        NSLayoutConstraint.activate([
            // Explicit height: no intrinsic size, would collapse in a stack.
            heightAnchor.constraint(equalToConstant: 52),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            icon.widthAnchor.constraint(equalToConstant: 19)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundCornersAsPill()
    }
}

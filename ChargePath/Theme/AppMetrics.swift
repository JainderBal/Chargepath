//
//  AppMetrics.swift
//  ChargePath
//
//  Spacing / sizing constants. The mockup's token row calls out an "8pt grid"
//  and a "44px min target", so layout code pulls from here instead of using
//  magic numbers.
//

import CoreGraphics

enum AppMetrics {
    /// 8-pt spacing scale.
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space8: CGFloat = 32

    /// Minimum hit target (Apple HIG + mockup token).
    static let minTapTarget: CGFloat = 44

    // Corner radii used across the mockup. Pill shapes are NOT a giant
    // constant here — an out-of-bounds cornerRadius stops the layer fill/
    // border rendering on current iOS. Pill views call `roundCornersAsPill()`
    // from `layoutSubviews` instead.
    static let radiusCard: CGFloat = 24
    static let radiusSheet: CGFloat = 30
    static let radiusChip: CGFloat = 18

    /// Border weight of the "hand-drawn" outline style.
    static let hairline: CGFloat = 2

    /// Bottom-sheet detent heights approximated from the mockup
    /// (sheet 498pt, filter sheet 550pt over an 852pt canvas).
    static let stationSheetMediumFraction: CGFloat = 0.58
    static let filterSheetMediumFraction: CGFloat = 0.64
}

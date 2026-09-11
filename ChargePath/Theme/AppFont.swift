//
//  AppFont.swift
//  ChargePath
//
//  The mockup uses three type families:
//    • "Bagel Fat One"  → big rounded display headers
//    • "Zilla Slab"     → slab-serif for titles / labels
//    • SF Pro (system)  → body copy
//
//  Custom font files are not bundled in this scaffold, so we approximate:
//  display headers use a heavy rounded system face, slab titles use the
//  system serif face. Swap in the real UIFontDescriptors here (and add the
//  .ttf to Resources + Info.plist `UIAppFonts`) to match the mockup exactly.
//
//  Every face is scaled with `UIFontMetrics` so the app respects the user's
//  Dynamic Type setting. `label.adjustsFontForContentSizeCategory` is set on
//  by the `UILabel` convenience initialiser (see UIKitHelpers).
//

import UIKit

enum AppFont {

    /// Big rounded header (mockup "Bagel Fat One").
    static func display(_ size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .heavy)
        let face = base.fontDescriptor.withDesign(.rounded)
            .map { UIFont(descriptor: $0, size: size) } ?? base
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: face)
    }

    /// Slab-serif title / label (mockup "Zilla Slab").
    static func slab(_ size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let face = base.fontDescriptor.withDesign(.serif)
            .map { UIFont(descriptor: $0, size: size) } ?? base
        return UIFontMetrics(forTextStyle: .headline).scaledFont(for: face)
    }

    /// Body / secondary copy (system).
    static func body(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let face = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: face)
    }
}

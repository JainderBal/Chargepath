//
//  AppColor.swift
//  ChargePath
//
//  The retro tricolor palette from the design mockup's token row. Names and
//  hex values are taken verbatim from `tokens` in ChargePath.dc.html.
//
//  These are deliberately fixed colours (not asset-catalog dynamic colours):
//  the design is a single committed light look — the "cream / ink" scheme is
//  the identity, so it does not invert for Dark Mode.
//

import UIKit

enum AppColor {
    static let cream     = UIColor(hex: 0xFFF6E3) // primary surface
    static let ink       = UIColor(hex: 0x3B1F17) // text, borders, "hard shadow"
    static let gold      = UIColor(hex: 0xF5B335) // primary accent / selected
    static let orange    = UIColor(hex: 0xE5622D) // call-to-action buttons
    static let rust      = UIColor(hex: 0xC4452C) // tertiary accent / tags
    static let sky        = UIColor(hex: 0x3E86D6) // route / info
    static let available = UIColor(hex: 0x2F7A55) // "Available" status
    static let sand      = UIColor(hex: 0xEFE0BE) // inset track / muted fill
    static let parchment = UIColor(hex: 0xFFFDF6) // raised card fill
    static let ground    = UIColor(hex: 0xE7D7B6) // page backdrop
    static let stone     = UIColor(hex: 0x8A6B54) // secondary text
    static let mapWater  = UIColor(hex: 0xC9DCEF)

    /// Colour for a `PortStatus` badge (mockup `statusColor`).
    static func status(_ status: PortStatus) -> UIColor {
        switch status {
        case .available: return available
        case .inUse:     return gold
        case .offline:   return UIColor(hex: 0xB0958A)
        case .unknown:   return sand
        }
    }

    /// Foreground colour to pair with `status(_:)` (mockup `statusFg`).
    static func statusForeground(_ status: PortStatus) -> UIColor {
        status == .inUse ? ink : cream
    }
}

extension UIColor {
    /// 0xRRGGBB literal initialiser — keeps the palette table readable.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue:  CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

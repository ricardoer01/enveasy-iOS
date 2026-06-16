//
//  Haptics.swift
//  inveasy
//

import UIKit

/// Thin wrapper around the UIKit haptic feedback generators so call sites
/// read as one-liners and don't have to know about generator setup.
enum Haptics {
    /// A short impact — use for direct manipulation (e.g. tapping an
    /// add-to-cart button).
    @MainActor
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// A semantic notification — use for completion of a multi-step flow
    /// (e.g. order placed) or for explicit failures.
    @MainActor
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

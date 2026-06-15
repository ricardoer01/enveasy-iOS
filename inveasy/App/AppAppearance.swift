//
//  AppAppearance.swift
//  inveasy
//

import SwiftUI

/// User-selectable color scheme override. Persisted to `UserDefaults` via
/// `@AppStorage("appearance")`; resolves to a `ColorScheme?` to drive
/// `preferredColorScheme` at the app root (a nil scheme means "follow the
/// system setting").
enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Sistema"
        case .light:  return "Claro"
        case .dark:   return "Oscuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

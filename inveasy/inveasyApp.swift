//
//  inveasyApp.swift
//  inveasy
//

import SwiftUI

@main
struct inveasyApp: App {
    @State private var appState = AppState()
    @State private var cart = CartStore()
    @AppStorage("appearance") private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(cart)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}

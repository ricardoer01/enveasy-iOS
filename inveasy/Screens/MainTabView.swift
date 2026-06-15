//
//  MainTabView.swift
//  inveasy
//

import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var app
    @Environment(CartStore.self) private var cart

    var body: some View {
        TabView {
            CatalogView(client: app.client)
                .tabItem { Label("Catálogo", systemImage: "bag") }

            CartView()
                .tabItem { Label("Carrito", systemImage: "cart") }
                .badge(cart.lineCount)

            OrdersView(client: app.client)
                .tabItem { Label("Pedidos", systemImage: "list.bullet.rectangle") }

            AccountView()
                .tabItem { Label("Cuenta", systemImage: "person.crop.circle") }
        }
    }
}

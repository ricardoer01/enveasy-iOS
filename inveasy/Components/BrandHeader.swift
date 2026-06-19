//
//  BrandHeader.swift
//  inveasy
//

import SwiftUI

/// Persistent brand mark shown at the top of every screen. The blue fill
/// extends into the status bar safe area; the text stays below it.
struct BrandHeader: View {
    var body: some View {
        Text("Inveasy")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.ignoresSafeArea(edges: .top))
    }
}

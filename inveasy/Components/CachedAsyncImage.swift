//
//  CachedAsyncImage.swift
//  inveasy
//

import SwiftUI

/// Drop-in replacement for `AsyncImage` that routes through `ImageCache`.
///
/// Mirrors AsyncImage's phase API so existing call sites can swap one for the
/// other without changing the surrounding view code.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await load()
            }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }
        do {
            let image = try await ImageCache.shared.image(for: url)
            if Task.isCancelled { return }
            phase = .success(Image(uiImage: image))
        } catch {
            if Task.isCancelled { return }
            phase = .failure(error)
        }
    }
}

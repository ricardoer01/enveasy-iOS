//
//  Skeleton.swift
//  inveasy
//

import SwiftUI

/// Greyed-out rounded rectangle with a slow shimmer. Use it as a building
/// block for content placeholders while the real data is in flight.
struct SkeletonRectangle: View {
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.tertiarySystemFill))
            .modifier(ShimmerModifier())
    }
}

/// Sweeps a soft highlight across the view to convey "loading".
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { proxy in
                LinearGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0),
                        .white.opacity(0.35),
                        .white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.6)
                .offset(x: proxy.size.width * phase)
                .blendMode(.plusLighter)
                .animation(
                    .linear(duration: 1.2).repeatForever(autoreverses: false),
                    value: phase
                )
            }
            .mask(content)
        )
        .onAppear { phase = 1.6 }
    }
}

/// Product card placeholder used by the catalog grid while products are loading.
struct ProductCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonRectangle(cornerRadius: 10)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            SkeletonRectangle(cornerRadius: 4)
                .frame(height: 14)
            SkeletonRectangle(cornerRadius: 4)
                .frame(width: 80, height: 14)
            HStack {
                SkeletonRectangle(cornerRadius: 4)
                    .frame(width: 60, height: 16)
                Spacer()
                SkeletonRectangle(cornerRadius: 4)
                    .frame(width: 24, height: 12)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Order row placeholder used by the orders list while history is loading.
struct OrderRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                SkeletonRectangle(cornerRadius: 4)
                    .frame(width: 120, height: 16)
                SkeletonRectangle(cornerRadius: 4)
                    .frame(width: 80, height: 12)
                SkeletonRectangle(cornerRadius: 8)
                    .frame(width: 90, height: 18)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                SkeletonRectangle(cornerRadius: 4)
                    .frame(width: 70, height: 14)
                SkeletonRectangle(cornerRadius: 4)
                    .frame(width: 40, height: 12)
            }
        }
        .padding(.vertical, 4)
    }
}

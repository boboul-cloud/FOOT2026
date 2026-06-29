// PinchToZoom.swift
// FOOT2026
// Reusable two-finger zoom: pinch to magnify a whole page, drag to pan once
// zoomed, double-tap to toggle. Normal one-finger scrolling stays active at 1×.

import SwiftUI

private struct PinchToZoom: ViewModifier {
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    func body(content: Content) -> some View {
        GeometryReader { geo in
            content
                .scaleEffect(scale)
                .offset(offset)
                .clipped()
                // Pan only while zoomed; high priority so it beats the List's own
                // scroll. At 1× it's masked off so normal scrolling stays active.
                .highPriorityGesture(pan(in: geo.size),
                                     including: scale > minScale ? .gesture : .subviews)
                // Two-finger pinch coexists with one-finger scrolling.
                .simultaneousGesture(magnify(in: geo.size))
                .animation(.interactiveSpring(duration: 0.25), value: scale)
                .animation(.interactiveSpring(duration: 0.25), value: offset)
        }
    }

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, minScale), maxScale)
                offset = clamp(offset, in: size)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale { resetPan() } else { lastOffset = offset }
            }
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(width: lastOffset.width + value.translation.width,
                                      height: lastOffset.height + value.translation.height)
                offset = clamp(proposed, in: size)
            }
            .onEnded { _ in lastOffset = offset }
    }

    /// Keeps the panned content within its own scaled bounds so you can reach
    /// every edge without dragging it into empty space.
    private func clamp(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let maxX = max(0, (scale - 1) * size.width  / 2)
        let maxY = max(0, (scale - 1) * size.height / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    private func resetPan() {
        offset = .zero
        lastOffset = .zero
    }
}

extension View {
    /// Adds two-finger pinch-to-zoom (with drag-to-pan when zoomed) to a page.
    func pinchToZoom() -> some View {
        modifier(PinchToZoom())
    }
}

// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import CoreGraphics
import Foundation

enum FocusScrollMotion {
    /// Default duration, in seconds, of the driven vertical focus-scroll settle.
    static let settleDuration: CFTimeInterval = 0.6

    /// Eased progress for the focus-scroll settle. Cubic ease-out: fast start,
    /// decelerating to a gentle stop. `t` is linear progress in 0...1.
    static func ease(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }

    // MARK: - Follow (the tvOS focus-scroll model)

    /// Fraction of the remaining distance left after each millisecond (time constant ~151 ms).
    static let convergencePerMillisecond = 0.9934
    /// Edge margin the focused item keeps when a long list scrolls.
    static let edgeInset: CGFloat = 180

    struct Follower {
        private(set) var position: CGFloat
        private var startPosition: CGFloat
        // The acceleration limit applies to displacement per callback, not points per second.
        private var displacement: CGFloat = 0

        init(position: CGFloat) {
            self.position = position
            startPosition = position
        }

        mutating func translate(by delta: CGFloat) {
            position += delta
            startPosition += delta
        }

        mutating func advance(toward target: CGFloat, elapsed: CFTimeInterval, viewport: CGFloat) -> Bool {
            let milliseconds = floor(elapsed * 1000)
            guard milliseconds >= 1 else { return false }
            let remaining = target - position
            if abs(remaining) < 0.5 {
                position = target
                displacement = 0
                return true
            }
            let convergence = CGFloat(pow(convergencePerMillisecond, milliseconds))
            var acceleration = remaining * (1 - convergence) - displacement
            if acceleration * remaining > 0 {
                acceleration = max(-10, min(10, acceleration))
            }
            displacement += acceleration
            if viewport > 0, abs(position - startPosition) >= viewport, abs(remaining) >= 2 * viewport {
                position = target - (remaining > 0 ? 2 : -2) * viewport
            }
            position += displacement
            return false
        }
    }

    /// Smallest offset change that keeps `frame` at least `edgeInset` inside a
    /// viewport of `height` resting at `offset`. An item too tall to fit is centred.
    static func minimalOffset(revealing frame: CGRect, from offset: CGFloat, height: CGFloat) -> CGFloat {
        let inset = height >= 2 * edgeInset ? edgeInset : 0
        if frame.height > height - 2 * inset { return frame.midY - height / 2 }
        if frame.minY < offset + inset { return frame.minY - inset }
        if frame.maxY > offset + height - inset { return frame.maxY - height + inset }
        return offset
    }
}

// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Foundation

enum PlaybackEndTime {
    static func estimate(from now: Date, remaining: TimeInterval, speed: Float) -> Date {
        let rate = speed.isFinite && speed > 0 ? Double(speed) : 1
        return now.addingTimeInterval(remaining / rate)
    }
}

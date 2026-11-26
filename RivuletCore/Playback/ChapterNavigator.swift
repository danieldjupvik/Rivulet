// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

//
//  ChapterNavigator.swift
//  Rivulet
//
//  Chapter lookup and snap targeting for playback.
//

import Foundation

nonisolated enum ChapterNavigator {
    static func activeIndex(at time: TimeInterval, duration: TimeInterval, chapters: [PlexChapter]) -> Int? {
        guard time.isFinite, time >= 0, duration <= 0 || time < duration else { return nil }
        var active: (index: Int, start: Int)?
        for (index, chapter) in chapters.enumerated() {
            let start = chapter.startTimeOffset ?? 0
            guard time >= TimeInterval(start) / 1000 else { continue }
            if let active, start <= active.start {
                guard start == active.start, chapter.startTimeOffset != nil,
                      chapters[active.index].startTimeOffset == nil else { continue }
            }
            active = (index, start)
        }
        guard let active else { return nil }
        if let end = chapters[active.index].endTimeOffset, end > active.start, time >= TimeInterval(end) / 1000 {
            return nil
        }
        return active.index
    }

    /// Next/previous chapter start relative to `from`. Backward snaps
    /// within 2s of a boundary skip to the chapter before it.
    static func snapTarget(from time: TimeInterval, chapterStarts: [TimeInterval], forward: Bool) -> TimeInterval? {
        let sorted = chapterStarts.sorted()
        if forward {
            return sorted.first { $0 > time }
        } else {
            return sorted.last { $0 < time - 2 }
        }
    }
}

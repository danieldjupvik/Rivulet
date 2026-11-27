// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import Testing
import XCTest
@testable import Rivulet

final class ChapterNavigatorTests: XCTestCase {
    let starts: [TimeInterval] = [0, 300, 900, 1800]

    func testForwardSnapsToNextStart() {
        XCTAssertEqual(ChapterNavigator.snapTarget(from: 100, chapterStarts: starts, forward: true), 300)
        XCTAssertEqual(ChapterNavigator.snapTarget(from: 300, chapterStarts: starts, forward: true), 900)
    }

    func testForwardAtLastChapterReturnsNil() {
        XCTAssertNil(ChapterNavigator.snapTarget(from: 1900, chapterStarts: starts, forward: true))
    }

    func testBackwardSnapsToPreviousStart() {
        XCTAssertEqual(ChapterNavigator.snapTarget(from: 1000, chapterStarts: starts, forward: false), 900)
        // Just past a boundary goes to the PREVIOUS chapter, not back to
        // the same boundary (2s grace, like track-skip in music apps).
        XCTAssertEqual(ChapterNavigator.snapTarget(from: 901, chapterStarts: starts, forward: false), 300)
    }

    func testEmptyChaptersReturnsNil() {
        XCTAssertNil(ChapterNavigator.snapTarget(from: 100, chapterStarts: [], forward: true))
    }
}

struct ChapterHighlightTests {
    @Test(arguments: [(0.5, 0), (1.0, 1), (2.0, nil), (3.0, 2), (4.0, nil)] as [(Double, Int?)])
    func usesNextStartAndRespectsExplicitEnds(_ input: (Double, Int?)) {
        let (position, expected) = input
        let chapters = [chapter(), chapter(start: 1_000, end: 2_000), chapter(start: 3_000)]
        #expect(ChapterNavigator.activeIndex(at: position, duration: 4, chapters: chapters) == expected)
    }

    @Test(arguments: [false, true])
    func explicitZeroWinsOverAMissingStart(reversed: Bool) {
        let inferred = chapter(end: 500)
        let explicit = chapter(start: 0, end: 10_000)
        let chapters = reversed ? [explicit, inferred] : [inferred, explicit]
        #expect(ChapterNavigator.activeIndex(at: 1, duration: 10, chapters: chapters) == (reversed ? 0 : 1))
    }

    private func chapter(start: Int? = nil, end: Int? = nil) -> PlexChapter {
        PlexChapter(id: nil, tag: nil, index: nil, startTimeOffset: start, endTimeOffset: end, thumb: nil)
    }
}

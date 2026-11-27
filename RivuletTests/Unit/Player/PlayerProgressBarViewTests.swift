// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import Testing
import UIKit
@testable import Rivulet

@Suite("PlayerProgressBarView")
struct PlayerProgressBarViewTests {
    private func color(_ type: String) -> UIColor {
        PlayerProgressBarView.color(for: PlexMarker(type: type, startTimeOffset: 0, endTimeOffset: 30000))
    }

    @Test("intro, credits and ads each get their own tint")
    func markerKindsAreDistinct() {
        let colors = ["intro", "credits", "commercial"].map(color)
        #expect(Set(colors).count == 3)
    }

    @Test("marker tints are translucent, not solid system colors")
    func markerTintsAreSoft() {
        for type in ["intro", "credits", "commercial"] {
            var alpha: CGFloat = 0
            color(type).getRed(nil, green: nil, blue: nil, alpha: &alpha)
            #expect(alpha < 1)
        }
    }

    @Test
    @MainActor
    func latePortraitPreviewFitsWithoutClippingChapterTitle() throws {
        let bar = PlayerProgressBarView(frame: CGRect(x: 80, y: 900, width: 1760, height: 64))
        let size = CGSize(width: 90, height: 160)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            context.fill(CGRect(origin: .zero, size: size))
        }
        let title = "A chapter title wider than the portrait preview at either end of the timeline"
        let chapter = PlexChapter(id: 1, tag: title, index: 0, startTimeOffset: 0, endTimeOffset: nil, thumb: nil)

        for time in [0.0, 50, 99.999] {
            bar.update(currentTime: 0, duration: 100, isScrubbing: true, scrubTime: time,
                       scrubThumbnail: nil, markers: [], chapters: [chapter])
            bar.setScrubThumbnail(image)
            let label = try #require(bar.subviews.compactMap { $0 as? UILabel }
                .first { $0.text?.contains(title.uppercased()) == true })
            let preview = try #require(bar.subviews.first { view in
                view.subviews.contains { ($0 as? UIImageView)?.image === image }
            })

            #expect(abs(preview.bounds.height - 225) < 0.01)
            #expect(abs(preview.bounds.width - 225 * 9 / 16) < 0.01)
            #expect(label.frame.width > preview.frame.width)
            #expect(label.frame.minX >= bar.bounds.minX)
            #expect(label.frame.maxX <= bar.bounds.maxX)
            if time == 50 { #expect(label.center.x == preview.center.x) }
        }
    }

    @Test(arguments: [false, true])
    @MainActor
    func previewExitCanBeInterruptedByAFreshScrub(usedWheel: Bool) throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let bar = PlayerProgressBarView(frame: CGRect(x: 80, y: 900, width: 1760, height: 64))
        window.addSubview(bar)
        bar.animatesScrubPreviewExit = true
        defer { bar.stopScrubPreviewExit() }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 9))
        let firstImage = renderer.image { _ in }
        let nextImage = renderer.image { _ in }
        func update(scrubbing: Bool, image: UIImage? = nil, wheel: Bool = false) {
            bar.update(currentTime: 20, duration: 100, isScrubbing: scrubbing, scrubTime: 50,
                       scrubThumbnail: image, markers: [], chapters: [], isWheelScrubbing: wheel)
        }

        update(scrubbing: true, image: firstImage, wheel: usedWheel)
        if usedWheel { update(scrubbing: true) }
        let preview = try #require(bar.subviews.first { view in
            view.subviews.contains { ($0 as? UIImageView)?.image === firstImage }
        })
        update(scrubbing: false)
        update(scrubbing: false)
        #expect(preview.transform.isIdentity == (usedWheel || UIAccessibility.isReduceMotionEnabled))

        update(scrubbing: true, image: nextImage)
        #expect(preview.transform.isIdentity)
        #expect(preview.alpha == 1)
        #expect(preview.subviews.contains { ($0 as? UIImageView)?.image === nextImage })
    }
}

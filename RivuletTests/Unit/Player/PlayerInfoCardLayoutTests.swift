// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Testing
import UIKit
@testable import Rivulet

@MainActor
struct PlayerInfoCardLayoutTests {
    @Test(arguments: ["movie", "episode"])
    func artworkCandidatesPreserveInfoPrecedence(_ kind: String) {
        var metadata = PlexMetadata(ratingKey: "m1", type: kind, title: "Title")
        metadata.thumb = "/poster"
        metadata.art = "/backdrop"
        metadata.parentThumb = "/season"
        metadata.grandparentThumb = "/series"
        let vm = UniversalPlayerViewModel(metadata: metadata, serverURL: "http://plex.local", authToken: "t")
        let paths = vm.infoArtworkURLs.map(\.path)
        #expect(paths == (kind == "episode" ? ["/poster", "/season", "/series"] : ["/poster", "/backdrop"]))
    }

    @Test(arguments: [
        ("https://images.example/still?w=640", "https://images.example/still?w=640"),
        ("/still?w=640", "http://plex.local/still?w=640&X-Plex-Token=t"),
    ])
    func plexEpisodeStillURLsPreserveTheirQueries(_ input: (String, String)) {
        let (thumb, expectedURL) = input
        var metadata = PlexMetadata(ratingKey: "e1", type: "episode")
        metadata.thumb = thumb
        metadata.parentThumb = "/season"
        let vm = UniversalPlayerViewModel(metadata: metadata, serverURL: "http://plex.local", authToken: "t")
        #expect(vm.infoArtworkURLs.map(\.absoluteString) == [expectedURL, "http://plex.local/season?X-Plex-Token=t"])
    }

    @Test(arguments: [60, 160, 720])
    func adaptiveArtworkFallsBackAndFitsBesideTheText(_ imageWidth: Int) async throws {
        let missing = try #require(URL(string: "https://artwork.test/missing"))
        let fallback = try #require(URL(string: "https://artwork.test/wide"))
        let image = UIGraphicsImageRenderer(size: CGSize(width: imageWidth, height: 90)).image { _ in }
        var requests = [URL]()
        let card = PlayerInfoCardView(content: .init(
            posterURL: missing, title: "Episode", summary: nil, genre: nil, runtime: nil,
            badges: [], layout: .adaptiveArtwork, fallbackPosterURLs: [fallback])) { url in
                requests.append(url)
                return url == fallback ? image : nil
            }
        let host = layout(card)
        let poster = try #require(card.subviews.compactMap { $0 as? UIImageView }.first)
        #expect(poster.isHidden)
        try await waitForPlayerCondition { poster.image != nil }
        host.setNeedsLayout()
        host.layoutIfNeeded()
        card.layoutIfNeeded()
        #expect(requests == [missing, fallback])
        #expect(poster.isHidden == false)
        #expect(poster.bounds.height == PlayerInfoCardView.Metrics.poster.height)
        let naturalWidth = PlayerInfoCardView.Metrics.poster.height * image.size.width / image.size.height
        let summary = try #require(card.subviews.compactMap { $0 as? PlayerSummaryButton }.first)
        let text = try #require(summary.subviews.compactMap { $0 as? PlayerSummaryTextView }.first)
        if imageWidth == 720 {
            #expect(poster.bounds.width > 0 && poster.bounds.width < naturalWidth)
            #expect(text.bounds.width >= PlayerInfoCardView.Metrics.actionWidth)
        } else {
            #expect(abs(poster.bounds.width - naturalWidth) < 1)
        }
    }

    @Test
    func removingInfoCardCancelsItsPendingArtworkLoad() async throws {
        let url = try #require(URL(string: "https://artwork.test/pending"))
        var finishLoad: CheckedContinuation<Void, Never>?
        defer { finishLoad?.resume() }
        var wasCancelled: Bool?
        var card: PlayerInfoCardView? = PlayerInfoCardView(content: .init(
            posterURL: url, title: "Episode", summary: nil, genre: nil, runtime: nil,
            badges: [], layout: .adaptiveArtwork)) { _ in
                await withCheckedContinuation { finishLoad = $0 }
                wasCancelled = Task.isCancelled
                return nil
            }
        weak var dismissedCard = card
        try await waitForPlayerCondition { finishLoad != nil }
        card = nil
        #expect(dismissedCard == nil)
        finishLoad?.resume()
        finishLoad = nil
        try await waitForPlayerCondition { wasCancelled != nil }
        #expect(wasCancelled == true)
    }

    @Test(arguments: [false, true])
    func playbackInfoAndInsightsShareFullPlexMetadata(firstRequestFails: Bool) async throws {
        var listing = PlexMetadata(ratingKey: "movie", type: "movie", title: "Movie")
        listing.rating = 6
        var detail = listing
        detail.rating = nil
        detail.summary = "Full metadata summary"
        detail.Rating = [PlexRatingEntry(image: "rottentomatoes://image.rating.ripe", value: 9, type: "critic")]
        detail.Role = [PlexRole(tag: "Lead Actor")]
        let vm = UniversalPlayerViewModel(metadata: listing, serverURL: "http://plex.local", authToken: "t")
        var requests: [String] = []
        vm.plexMetadataFetch = { _, _, key in
            requests.append(key)
            if firstRequestFails, requests.count == 1 { throw URLError(.timedOut) }
            return detail
        }
        #expect(vm.needsInfoReviewRating)
        #expect(requests.isEmpty)
        await vm.loadPlexPlaybackMetadata()
        #expect(requests == ["movie"])
        #expect(vm.metadata.summary == (firstRequestFails ? nil : detail.summary))
        let card = PlayerInfoCardView(content: .init(
            title: "Movie", summary: nil, genre: nil, runtime: nil, badges: ["HD"],
            layout: .adaptiveArtwork, reviewRating: vm.infoReviewRating),
            loadRating: { try await vm.resolvedInfoReviewRating() })
        let metadata = try #require(card.subviews.compactMap { $0 as? UIStackView }.first)
        func scoreText() -> String? {
            (metadata.arrangedSubviews.dropFirst().first as? UIStackView)?
                .arrangedSubviews.compactMap { ($0 as? UILabel)?.text }.last
        }

        #expect(scoreText() == vm.infoReviewRating?.badgeText)
        try await waitForPlayerCondition { scoreText() == "90%" }
        #expect(try await vm.resolvedInfoReviewRating()?.value == 9)
        await vm.loadInsightsCast()
        #expect(vm.insightsCast.map(\.name) == ["Lead Actor"])
        #expect(requests == (firstRequestFails ? ["movie", "movie"] : ["movie"]))
    }

    @Test
    func stoppingPlaybackDiscardsThePendingInfoRating() async throws {
        var listing = PlexMetadata(ratingKey: "movie", type: "movie")
        listing.rating = 6
        var finishLoad: CheckedContinuation<PlexMetadata, Never>?
        let noRating = PlexMetadata(ratingKey: "movie", type: "movie")
        defer { finishLoad?.resume(returning: noRating) }
        let vm = UniversalPlayerViewModel(metadata: listing, serverURL: "http://plex.local", authToken: "t")
        vm.plexMetadataFetch = { _, _, _ in
            await withCheckedContinuation { finishLoad = $0 }
        }
        let pending = Task { try await vm.resolvedInfoReviewRating() }
        try await waitForPlayerCondition { finishLoad != nil }

        vm.stopPlayback()
        let continuation = try #require(finishLoad)
        finishLoad = nil
        continuation.resume(returning: noRating)

        await #expect(throws: CancellationError.self) { try await pending.value }
    }

    @Test
    func episodeMetadataLaysOutGenreEpisodeNumberAndRuntimeInOrder() throws {
        let episode = String(localized: "S\(1), E\(2)")
        let runtime = MediaDetailChromeView.formatRuntime(118 * 60)
        let card = PlayerInfoCardView(content: .init(
            title: "Episode", summary: nil, genre: "Drama", runtime: runtime, badges: [],
            layout: .adaptiveArtwork, episodeLabel: episode))
        let metadata = try #require(card.subviews.compactMap { $0 as? UIStackView }.first)
        let label = try #require(metadata.arrangedSubviews.compactMap { $0 as? UILabel }.first)
        #expect(label.text == "Drama • \(episode) • \(runtime)")
    }

    @Test
    func summaryFocusTracksWidthAndReplacementText() throws {
        let text = String(repeating: "Text with space to wrap. ", count: 8)
        let card = PlayerInfoCardView(content: .init(
            title: "Movie", summary: text, genre: nil, runtime: nil, badges: [], layout: .adaptiveArtwork))
        let host = layout(card, width: 760)
        let summary = try #require(card.subviews.compactMap { $0 as? PlayerSummaryButton }.first)
        #expect(summary.canBecomeFocused)

        host.frame.size.width = 1760
        host.layoutIfNeeded()
        #expect(summary.canBecomeFocused == false)

        summary.setText(String(repeating: text, count: 8))
        host.layoutIfNeeded()
        summary.layoutIfNeeded()
        #expect(summary.canBecomeFocused)
        summary.setText("Short summary")
        host.layoutIfNeeded()
        summary.layoutIfNeeded()
        #expect(summary.canBecomeFocused == false)
    }

    @Test
    func actorCardHasAFocusTargetBeforeBiographyAndFilmographyLoad() throws {
        let person = MediaPerson(id: "actor", name: "Actor", role: nil, imageURL: nil)
        let actor = InsightsActorView(person: person)
        let bio = try #require(actor.preferredFocusEnvironments.first as? PlayerSummaryButton)
        #expect(bio.canBecomeFocused)

        actor.populate(PersonDetail(id: person.id, name: person.name, biography: "Short bio.",
                                    portraitURL: nil, movies: [], shows: []))
        #expect(bio.canBecomeFocused)
    }

    @Test(arguments: [false, true])
    func moreCueAndFadeFollowTheLastVisibleParagraph(_ rtl: Bool) throws {
        let arabic = "هذا وصف طويل للفيلم يحتوي على عدة جمل وأحداث مهمة. "
        let english = "This is a long movie summary with several sentences and important events. "
        let first = rtl ? "Intro." : "مقدمة."
        let summary = PlayerSummaryTextView(text: first + "\n" + String(repeating: rtl ? arabic : english, count: 12), lines: 3)
        let font = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: summary.traitCollection)
        summary.frame.size = CGSize(width: 540, height: ceil(font.lineHeight) * 3)
        summary.layoutIfNeeded()
        summary.layoutIfNeeded()

        let cue = try #require(summary.subviews.compactMap { $0 as? UILabel }.first)
        let text = try #require(summary.subviews.compactMap { $0 as? UITextView }.first)
        let fade = try #require(text.layer.mask?.sublayers?.compactMap { $0 as? CAGradientLayer }.first)
        let glyphs = text.layoutManager.glyphRange(for: text.textContainer)
        let line = text.layoutManager.lineFragmentRect(forGlyphAt: NSMaxRange(glyphs) - 1, effectiveRange: nil)
        #expect(summary.isTextTruncated)
        #expect(cue.isHidden == false)
        #expect(abs((rtl ? cue.frame.minX : summary.bounds.width - cue.frame.maxX) - 5) < 1)
        #expect(abs((rtl ? fade.frame.minX - cue.frame.maxX : cue.frame.minX - fade.frame.maxX) - 5) < 1)
        #expect(fade.frame.minY == line.minY)
        #expect(fade.frame.maxY == line.maxY)
        #expect(line.contains(CGPoint(x: cue.frame.midX, y: cue.frame.midY)))
        #expect(fade.endPoint.x == (rtl ? 0 : 1))
    }

    @Test
    func moreAppearsOnlyWhenTextExceedsThreeLines() throws {
        let fits = "First line\nSecond line\nThird line"
        let summary = PlayerSummaryTextView(text: fits, lines: 3)
        let font = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: summary.traitCollection)
        summary.frame.size = CGSize(width: 540, height: ceil(font.lineHeight) * 3)
        summary.layoutIfNeeded()

        let cue = try #require(summary.subviews.compactMap { $0 as? UILabel }.first)
        #expect(summary.isTextTruncated == false)
        #expect(cue.isHidden)

        summary.setText(fits + "\nFourth line")
        summary.layoutIfNeeded()
        #expect(summary.isTextTruncated)
        #expect(cue.isHidden == false)
    }

    private func layout(_ card: PlayerInfoCardView, width: CGFloat = 1760) -> UIView {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 600))
        card.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: host.topAnchor),
            card.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: host.trailingAnchor),
        ])
        host.layoutIfNeeded()
        return host
    }

    private func waitForPlayerCondition(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(predicate())
    }

    @Test(arguments: [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge])
    func summaryFitsItsLineLimitAboveMetadata(_ category: UIContentSizeCategory) throws {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 1760, height: 600))
        host.traitOverrides.preferredContentSizeCategory = category
        let card = PlayerInfoCardView(content: .init(
            title: "Movie",
            summary: String(repeating: "A long movie summary for the player. ", count: 50),
            genre: "Drama",
            runtime: nil,
            badges: [],
            layout: .adaptiveArtwork))
        card.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: host.topAnchor),
            card.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: host.trailingAnchor),
        ])
        host.updateTraitsIfNeeded()
        host.layoutIfNeeded()

        let summary = try #require(card.subviews.compactMap { $0 as? PlayerSummaryButton }.first)
        let text = try #require(summary.subviews.compactMap { $0 as? PlayerSummaryTextView }.first)
        let metadata = try #require(card.subviews.compactMap { $0 as? UIStackView }.first)
        let textView = try #require(text.subviews.compactMap { $0 as? UITextView }.first)
        let manager = textView.layoutManager
        let glyphs = manager.glyphRange(for: textView.textContainer)
        let lineCount = category.isAccessibilityCategory ? 2 : 3
        var lines: [CGRect] = []
        manager.enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in lines.append(rect) }
        let lastLine = try #require(lines.last)
        #expect(lines.count == lineCount)
        #expect(text.bounds.height >= lastLine.maxY)
        #expect(summary.frame.maxY < metadata.frame.minY)
        #expect(metadata.frame.maxY < card.bounds.height)
        #expect(summary.canBecomeFocused)
        if !category.isAccessibilityCategory {
            #expect(card.bounds.height == PlayerInfoCardView.Metrics.height)
        }
    }
}

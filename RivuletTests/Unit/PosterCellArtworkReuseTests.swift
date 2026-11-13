import Testing
import TVUIKit
import UIKit
@testable import Rivulet

@Suite(.serialized)
@MainActor
struct PosterCellArtworkReuseTests {
    @Test
    func cachedRebindSkipsTheBlankArtworkStep() async throws {
        let first = try await cachedArtwork()
        let second = try await cachedArtwork()
        let cell = PosterCell(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let poster = try #require(cell.contentView.subviews.compactMap { $0 as? TVPosterView }.first)
        cell.configure(item: item(poster: first.url))
        #expect(poster.image === first.image)

        cell.prepareForReuse()
        #expect(poster.image === first.image)
        cell.configure(item: item(poster: second.url))
        #expect(poster.image === second.image)
        cell.prepareForReuse()
    }

    enum Fallback: CaseIterable {
        case uncached, missing, placeholder
    }

    @Test(arguments: [false, true])
    func aspectChangesResetGeometryBeforeApplyingCachedArtwork(startsSquare: Bool) async throws {
        let first = try await cachedArtwork()
        let second = try await cachedArtwork()
        let cell = PosterCell(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let poster = try #require(cell.contentView.subviews.compactMap { $0 as? TVPosterView }.first)
        cell.configure(item: item(poster: first.url, square: startsSquare))
        let assignments = ArtworkAssignments()
        let observation = poster.observe(\.image, options: .new) { _, change in
            MainActor.assumeIsolated {
                if let image = change.newValue ?? nil { assignments.images.append(image) }
            }
        }
        cell.prepareForReuse()
        cell.configure(item: item(poster: second.url, square: !startsSquare))
        withExtendedLifetime(observation) {
            #expect(assignments.images.count == 2)
            let expectedSize = startsSquare ? MediaRowMetrics.poster.art : MediaRowMetrics.music.art
            #expect(assignments.images.first?.size == expectedSize)
            #expect(assignments.images.last === second.image)
        }
        cell.prepareForReuse()
    }

    private final class ArtworkAssignments {
        var images: [UIImage] = []
    }

    @Test(arguments: Fallback.allCases)
    func fallbackClearsRetainedArtworkImmediately(fallback: Fallback) async throws {
        let cached = try await cachedArtwork()
        let cell = PosterCell(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let poster = try #require(cell.contentView.subviews.compactMap { $0 as? TVPosterView }.first)
        cell.configure(item: item(poster: cached.url))
        #expect(poster.image === cached.image)
        cell.prepareForReuse()

        switch fallback {
        case .uncached:
            cell.configure(item: item(poster: URL(string: "uncached-poster://fixture/cover")))
        case .missing:
            cell.configure(item: item(poster: nil))
        case .placeholder:
            cell.configurePlaceholder()
        }
        #expect(poster.image === PosterCell.blankArtwork)
        cell.prepareForReuse()
    }

    private func item(poster: URL?, square: Bool = false) -> MediaItem {
        MediaItem(
            ref: MediaItemRef(providerID: "test:poster-reuse", itemID: UUID().uuidString),
            kind: .movie, title: "Poster reuse", sortTitle: nil, overview: nil, year: nil, runtime: nil,
            isMusic: square,
            parentRef: nil, grandparentRef: nil, episodeNumber: nil, seasonNumber: nil, childProgress: nil,
            userState: MediaUserState(isPlayed: false, viewOffset: 0, isFavorite: false, lastViewedAt: nil),
            artwork: MediaArtwork(poster: poster, backdrop: nil, thumbnail: nil, logo: nil),
            parentArtwork: nil, grandparentArtwork: nil
        )
    }

    private func cachedArtwork() async throws -> (url: URL, image: UIImage) {
        let url = try #require(URL(string: "https://poster-reuse.invalid/\(UUID().uuidString).png"))
        let directory = try #require(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
            .appendingPathComponent("PlexImageCache", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sizedURL = ArtworkSizing.fitted(url, maxPixel: Int(ImageQuality.thumb.maxPixelSize))
        let file = directory.appendingPathComponent(sizedURL.absoluteString.sha256Hash())
        let artwork = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 90)).image { context in
            context.cgContext.setFillColor(UIColor.red.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 60, height: 90))
        }
        let data = try #require(artwork.pngData())
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let loaded = await ImageCacheManager.shared.image(for: url)
        let image = try #require(loaded)
        #expect(ImageCacheManager.shared.cachedImage(for: url) === image)
        return (url, image)
    }
}

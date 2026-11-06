import Testing
@testable import Rivulet

@MainActor
struct MediaCapabilityBadgesTests {
    @Test func emptySourceHasNoBadges() {
        #expect(MediaCapabilityBadges.detailed(qualityBadges: [], audioTracks: [], subtitleTracks: []).isEmpty)
    }

    @Test func detailedLabelsKeepFormatsAndRemoveLayoutSuffixes() {
        let badges = MediaCapabilityBadges.detailed(
            qualityBadges: ["4K", "DV", "HDR10+", " E-AC3 5.1(side) Atmos ", "", " (side) "],
            audioTracks: [], subtitleTracks: [])

        #expect(badges == ["4K", "DV", "HDR10+", "E-AC3 5.1 Atmos"])
    }

    @Test func accessibilityBadgesIncludeUnselectedTracksOnceAfterQuality() {
        let audio = audioTrack(title: "Audio DESCRIPTION")
        let subtitles = subtitleTrack(hearingImpaired: true)
        let badges = MediaCapabilityBadges.detailed(
            qualityBadges: ["1080p", "AAC 2.0"], audioTracks: [audio, audio],
            subtitleTracks: [subtitles, subtitles])

        #expect(badges == ["1080p", "AAC 2.0", "SDH", "AD"])
    }

    @Test func ordinaryTracksDoNotAddAccessibilityBadges() {
        let badges = MediaCapabilityBadges.detailed(
            qualityBadges: ["4K"], audioTracks: [audioTrack(title: "English Commentary")],
            subtitleTracks: [subtitleTrack(hearingImpaired: false)])

        #expect(badges == ["4K"])
    }

    @Test func audioDescriptionFallsBackToExtendedTitleOnlyWhenTitleIsMissing() {
        let fallback = MediaCapabilityBadges.detailed(
            qualityBadges: [], audioTracks: [audioTrack(extendedTitle: "Audio Description")], subtitleTracks: [])
        let titled = MediaCapabilityBadges.detailed(
            qualityBadges: [],
            audioTracks: [audioTrack(title: "English", extendedTitle: "Audio Description")], subtitleTracks: [])

        #expect(fallback == ["AD"])
        #expect(titled.isEmpty)
    }

    private func audioTrack(title: String? = nil, extendedTitle: String? = nil) -> AudioTrack {
        AudioTrack(
            id: "audio", index: 0, codec: "aac", profile: nil, channels: 2, channelLayout: "stereo",
            language: "en", title: title, extendedTitle: extendedTitle, bitrate: nil, samplingRate: nil,
            isDefault: false, isForced: false, isSelected: false)
    }

    private func subtitleTrack(hearingImpaired: Bool) -> SubtitleTrack {
        SubtitleTrack(
            id: "subtitle", index: 1, codec: "srt", language: "en", title: nil, extendedTitle: nil,
            isDefault: false, isForced: false, isHearingImpaired: hearingImpaired,
            isEmbedded: true, externalURL: nil, isSelected: false)
    }
}

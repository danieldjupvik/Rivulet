// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Foundation
import Testing
@testable import Rivulet

@MainActor
struct PlayerMetadataRulesTests {
    @Test(arguments: [
        ("Episode", "Series", "Episode"),
        (nil, "Series", "Series"),
        (" \n ", "Series", "Series"),
        (nil as String?, " \t ", nil as String?),
    ])
    func infoUsesTheSeriesTitleForAnUntitledEpisode(_ input: (String?, String, String?)) {
        let (episodeTitle, seriesTitle, expected) = input
        let metadata = PlexMetadata(type: "episode", title: episodeTitle, grandparentTitle: seriesTitle)
        let vm = UniversalPlayerViewModel(metadata: metadata, serverURL: "http://plex.local", authToken: "t")

        #expect(vm.infoTitle == (expected ?? String(localized: "Unknown")))
    }

    @Test(arguments: [(1, "Atmos"), (2, "DTS:X"), (3, "Atmos"), (4, nil as String?)])
    func infoAtmosBadgeMatchesDetailsForTheSelectedVersion(_ input: (Int, String?)) throws {
        let (version, expectedBadge) = input
        let metadata = try JSONDecoder().decode(PlexMetadata.self, from: Data("""
        {"ratingKey":"m1","type":"movie","Media":[
          {"id":1,"Part":[{"id":1,"Stream":[
            {"id":10,"streamType":2,"codec":"aac","selected":true},
            {"id":11,"streamType":2,"codec":"truehd","profile":"Dolby Atmos","default":true}
          ]}]},
          {"id":2,"Part":[{"id":2,"Stream":[
            {"id":20,"streamType":2,"codec":"dca","profile":"dts-x","default":true},
            {"id":21,"streamType":2,"codec":"eac3","profile":"Dolby Atmos","selected":true}
          ]}]},
          {"id":3,"Part":[{"id":3,"Stream":[{"id":30,"streamType":2,"codec":"eac3","profile":"Dolby Atmos"}]}]},
          {"id":4,"Part":[{"id":4,"Stream":[
            {"id":40,"streamType":2,"codec":"truehd","title":"Dolby Atmos","default":true}
          ]}]}
        ]}
        """.utf8))
        let serverURL = "http://plex.local"
        let authToken = "t"
        let detail = PlexMediaMapper.detail(metadata, providerID: "plex", serverURL: serverURL, authToken: authToken)
        let detailSource = try #require(detail.mediaSources.first { $0.id == String(version) })
        let vm = UniversalPlayerViewModel(metadata: metadata, serverURL: serverURL, authToken: authToken,
                                          preferredMediaID: String(version))
        #expect(vm.playingMediaID == String(version))
        #expect(detailSource.detailBadges == [expectedBadge].compactMap { $0 })
        #expect(vm.infoHasAtmos == detailSource.detailBadges.contains("Atmos"))
    }

    @Test
    func genreSelectionSkipsBlankValuesAndKeepsSourceOrder() {
        #expect(MediaGenre.firstNonempty(in: ["", " \t", " Drama\n", "Comedy"]) == "Drama")
        #expect(MediaGenre.firstNonempty(in: ["\n", " "]) == nil)
    }

    @Test(arguments: [(false, nil as String?, false), (true, nil, true), (false, "/library/streams/1", true)])
    func subtitleFormatNamesSidecarsWithoutLosingFlags(_ input: (Bool, String?, Bool)) {
        let (external, key, expectsExternalLabel) = input
        let track = MediaTrack(id: 1, name: "English", codec: "srt", isForced: true,
                               isHearingImpaired: true, subtitleKey: key, isExternal: external)
        let codec = "SRT"
        let format = expectsExternalLabel ? String(localized: "\(codec) External") : codec
        let expected = [String(localized: "Forced"), "SDH", format].joined(separator: " • ")
        #expect(track.subtitleMenuSubtitle == expected)
    }

    @Test
    func subtitleOrderingRemembersExplicitLanguageAfterTurningSubtitlesOff() throws {
        let suite = "SubtitleLanguageOrdering.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let previousDefaults = TrackIntentStore.defaults
        TrackIntentStore.defaults = defaults
        defer {
            TrackIntentStore.defaults = previousDefaults
            defaults.removePersistentDomain(forName: suite)
        }
        let english = MediaTrack(id: 1, name: "English", languageCode: "eng")
        let simplified = MediaTrack(id: 2, name: "Chinese (Simplified)", languageCode: "chi", languageTag: "zh-Hans")
        let traditional = MediaTrack(id: 3, name: "Chinese (Traditional)", languageCode: "chi", languageTag: "zh-Hant")
        TrackIntentStore.subtitleIntent = .track(language: "eng", forced: false, hearingImpaired: false, codec: nil)
        TrackIntentStore.saveSubtitlePick(traditional, audioLanguage: "eng")
        #expect(TrackIntentStore.subtitleIntent?.language == "chi")
        TrackIntentStore.saveSubtitlePick(nil, audioLanguage: "eng")

        #expect(TrackIntentStore.subtitleIntent == SubtitleIntent.off)
        let ordered = SubtitleLanguageOrdering.ordered(
            [simplified, english, traditional], preferredLanguages: ["en-US"],
            recentLanguage: TrackIntentStore.recentSubtitleLanguage, selectedTrackID: nil, lastTrackID: nil)
        #expect(ordered.map(\.id) == [english.id, traditional.id, simplified.id])
    }

    @Test
    func recentSubtitleLanguagePrefersExistingProfileIntentOverDevicePick() throws {
        let suite = "SubtitleProfileUpgrade.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let previousDefaults = TrackIntentStore.defaults
        TrackIntentStore.defaults = defaults
        defer {
            TrackIntentStore.defaults = previousDefaults
            defaults.removePersistentDomain(forName: suite)
        }
        TrackIntentStore.saveSubtitlePick(MediaTrack(id: 1, name: "French", languageCode: "fra"), audioLanguage: "eng")
        let deviceLanguage = TrackIntentStore.recentSubtitleLanguage
        defaults.set(42, forKey: PlexProfileSession.savedUserIDKey)
        #expect(TrackIntentStore.recentSubtitleLanguage == deviceLanguage)

        TrackIntentStore.subtitleIntent = .track(language: "fin", forced: false, hearingImpaired: false, codec: nil)
        #expect(TrackIntentStore.recentSubtitleLanguage == "fin")
        TrackIntentStore.saveSubtitlePick(nil, audioLanguage: "eng")
        #expect(TrackIntentStore.subtitleIntent == SubtitleIntent.off)
        #expect(TrackIntentStore.recentSubtitleLanguage == "fin")

        defaults.set(43, forKey: PlexProfileSession.savedUserIDKey)
        TrackIntentStore.subtitleIntent = .off
        #expect(TrackIntentStore.recentSubtitleLanguage == nil)
        defaults.removeObject(forKey: PlexProfileSession.savedUserIDKey)
        #expect(TrackIntentStore.recentSubtitleLanguage == deviceLanguage)
    }

    @Test
    func subtitleOrderingPromotesSelectedRecentTrackAfterPreferredLanguages() {
        let tracks = [
            MediaTrack(id: 1, name: "Generated", languageCode: "en"),
            MediaTrack(id: 2, name: "Finnish forced", languageCode: "fin", isForced: true),
            MediaTrack(id: 3, name: "English", languageCode: "eng"),
            MediaTrack(id: 4, name: "Finnish", languageCode: "fi"),
            MediaTrack(id: 5, name: "French", languageCode: "fr"),
        ]
        let ordered = SubtitleLanguageOrdering.ordered(
            tracks, preferredLanguages: ["en-US"], recentLanguage: "fi",
            selectedTrackID: 4, lastTrackID: 1)
        #expect(ordered.map(\.id) == [3, 4, 2, 5, 1])
    }

    @Test
    func genericCaptionsStayWithThePreferredRegionalLanguage() {
        let tracks = [
            MediaTrack(id: 1, name: "Finnish", languageCode: "fi"),
            MediaTrack(id: 2, name: "English", languageCode: "en"),
            MediaTrack(id: 3, name: "British English", languageCode: "en-GB"),
        ]
        let ordered = SubtitleLanguageOrdering.ordered(
            tracks, preferredLanguages: ["en-GB"], recentLanguage: "fi",
            selectedTrackID: 1, lastTrackID: nil)

        #expect(ordered.map(\.id) == [3, 2, 1])
    }

    @Test(arguments: [false, true], ["zh-Hans", "zh-CN"])
    func subtitleOrderingKeepsPlexChineseScriptsDistinct(_ reversed: Bool, _ simplifiedTag: String) throws {
        let streams = try JSONDecoder().decode([PlexStream].self, from: Data("""
        [
          {"id":101,"index":1,"streamType":3,"languageCode":"chi","languageTag":"\(simplifiedTag)"},
          {"id":102,"index":2,"streamType":3,"languageCode":"deu"},
          {"id":103,"index":3,"streamType":3,"languageCode":"chi","languageTag":"zh-TW"}
        ]
        """.utf8))
        let engine = (1...3).map { MediaTrack(id: $0, name: "Subtitle \($0)", streamIndex: $0) }
        let merged = TrackMerge.mergeSubtitles(engine: engine, plex: streams.map { MediaTrack(from: $0) })
        let simplified = merged[0]
        let german = merged[1]
        let traditional = merged[2]
        let tracks = reversed ? [german, simplified] : [simplified, german]
        let preferred = ["zh-Hant", "de"]

        let withoutTraditional = SubtitleLanguageOrdering.ordered(
            tracks, preferredLanguages: preferred, recentLanguage: nil, selectedTrackID: nil, lastTrackID: nil)
        #expect(withoutTraditional.map(\.id) == [2, 1])

        let withTraditional = SubtitleLanguageOrdering.ordered(
            tracks + [traditional], preferredLanguages: preferred, recentLanguage: nil, selectedTrackID: nil, lastTrackID: nil)
        #expect(withTraditional.map(\.id) == [3, 2, 1])
    }
}

// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import Foundation
import Testing
@testable import Rivulet

@MainActor
struct NorwegianTrackLanguageTests {
    @Test(arguments: ["no", "nor", "nb", "nob", "Norwegian", "Norwegian Bokmål"])
    func existingPreferencesSelectBokmal(language: String) {
        let code = TrackLanguage.preferenceCode(language)
        #expect(code == "nob")
        #expect(TrackLanguage.choices.filter { $0 == code }.count == 1)
        #expect(TrackLanguage.displayName(language, locale: Locale(identifier: "nb_NO")) == "Norsk Bokmål")
        #expect(TrackLanguage.displayName(language, locale: Locale(identifier: "en_US")) == "Norwegian Bokmål")
    }

    @Test func preservesExistingLanguageFormatting() {
        let locale = Locale(identifier: "nb_NO")
        #expect(TrackLanguage.displayName("eng", locale: locale) == "Engelsk")
    }

    @Test(arguments: ["nb-NO", "nb", "no-NO", "no"])
    func systemLanguageSelectsAvailableChoice(language: String) {
        let code = TrackLanguage.language(fromPreferred: [language, "en"])
        #expect(code == "nob")
        #expect(TrackLanguage.choices.contains(code))
    }

    @Test(arguments: ["no", "nor", "nb", "nob"], ["no", "nor", "nb", "nob"])
    func resolvesCompatibleTracks(preference: String, language: String) {
        let tracks = [track(1, "eng"), track(2, language)]
        let intent = SubtitleIntent.track(language: preference, forced: false, hearingImpaired: false, codec: nil)
        #expect(TrackIntentResolver.resolveSubtitle(intent: intent, in: tracks)?.id == 2)
        #expect(TrackIntentResolver.resolveAudio(intent: AudioIntent(language: preference), in: tracks,
                                               prefersAudioDescription: false)?.id == 2)
        #expect(TrackLanguage.isForeign(language, to: preference) == false)
        #expect(CaptionsOnMuteLogic.track(in: tracks, preferredLanguage: preference, audioLanguage: "eng")?.id == 2)
    }

    @Test(arguments: ["nn", "nno"])
    func nynorskRemainsDistinct(language: String) {
        #expect(TrackLanguage.matches(language, "nor") == false)
        #expect(TrackLanguage.matches(language, "nob") == false)
        let intent = SubtitleIntent.track(language: "nob", forced: false, hearingImpaired: false, codec: nil)
        #expect(TrackIntentResolver.resolveSubtitle(intent: intent, in: [track(1, language)]) == nil)
    }

    @Test func preservesTrackIdentity() {
        #expect(TrackLanguage.normalize("no") == "nor")
        #expect(TrackLanguage.normalize("nb") == "nob")
        let subtitle = track(1, "nor")
        #expect(SubtitleIntent(from: subtitle).language == "nor")
        #expect(TrackLanguage.matches(nil, "nob") == false)
        #expect(TrackLanguage.matches("", "") == false)
    }

    @Test func preservesSubtitleRanking() {
        let tracks = [
            track(1, "nor", hearingImpaired: true),
            track(2, "nob", forced: true),
            track(3, "nor", external: true),
            track(4, "nob"),
            track(5, "nb", codec: "ass")
        ]
        func pick(forced: Bool = false, sdh: Bool = false, codec: String? = nil) -> Int? {
            TrackIntentResolver.resolveSubtitle(
                intent: .track(language: "nob", forced: forced, hearingImpaired: sdh, codec: codec),
                in: tracks)?.id
        }
        #expect(pick() == 3)
        #expect(pick(sdh: true) == 1)
        #expect(pick(forced: true) == 2)
        #expect(pick(codec: "ass") == 5)
    }

    @Test func foreignAudioTreatsNorwegianAsBokmal() {
        let tracks = [track(1, "nor"), track(2, "nob", forced: true)]
        let intent = SubtitleIntent.foreignAudio(language: "nob", hearingImpaired: false)
        #expect(TrackIntentResolver.resolveSubtitle(intent: intent, in: tracks, audioLanguage: "no")?.id == 2)
        #expect(TrackIntentResolver.resolveSubtitle(intent: intent, in: tracks, audioLanguage: "eng")?.id == 1)
    }

    private func track(_ id: Int, _ language: String, forced: Bool = false,
                       hearingImpaired: Bool = false, codec: String = "srt", external: Bool = false) -> MediaTrack {
        MediaTrack(id: id, name: "Track \(id)", languageCode: language, codec: codec,
                   isForced: forced, isHearingImpaired: hearingImpaired, isExternal: external)
    }
}

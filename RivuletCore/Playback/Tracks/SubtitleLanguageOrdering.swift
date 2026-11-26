// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Foundation

enum SubtitleLanguageOrdering {
    static func ordered(_ languageTracks: [MediaTrack], preferredLanguages: [String],
                        recentLanguage: String?, selectedTrackID: Int?, lastTrackID: Int?) -> [MediaTrack] {
        let tracks = languageTracks.map { track in
            let tag = track.id == lastTrackID ? nil : languageTag(for: track)
            return (track: track, tag: tag)
        }
        let availableTags = Set(tracks.compactMap(\.tag)).sorted()

        func matches(for identifier: String?) -> [String] {
            guard let preference = languageTag(identifier) else { return [] }
            let preferenceLanguage = Locale.Language(identifier: preference)
            let preferenceScript = specifiedScript(for: preference, language: preferenceLanguage)
            let compatibleTags = availableTags.filter { tag in
                let language = Locale.Language(identifier: tag)
                guard language.languageCode == preferenceLanguage.languageCode else { return false }
                guard let preferenceScript, let script = specifiedScript(for: tag, language: language) else { return true }
                return script == preferenceScript
            }
            guard !compatibleTags.isEmpty else { return [] }
            return Bundle.preferredLocalizations(from: compatibleTags, forPreferences: [preference])
        }

        let preferred = preferredLanguages.flatMap(matches)
        let preferredRanks = Dictionary(preferred.enumerated().map { ($0.element, $0.offset) },
                                        uniquingKeysWith: { first, _ in first })
        let recent = matches(for: recentLanguage).first
        let recentMatches = tracks.filter { recent != nil && $0.tag == recent }
        let recentTrackID = recentMatches.first { $0.track.id == selectedTrackID }?.track.id
            ?? recentMatches.first?.track.id
        let options = tracks.map { track, tag in
            let rank: Int
            if track.id == lastTrackID {
                rank = preferred.count + 2
            } else if let tag, let index = preferredRanks[tag] {
                rank = index
            } else {
                rank = track.id == recentTrackID ? preferred.count : preferred.count + 1
            }
            return (track: track, rank: rank)
        }
        return options.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.track.subtitleMenuTitle.localizedCaseInsensitiveCompare(rhs.track.subtitleMenuTitle) == .orderedAscending
        }.map(\.track)
    }

    private static func specifiedScript(for tag: String, language: Locale.Language) -> Locale.Script? {
        let components = Locale.Language.Components(identifier: tag)
        return components.script ?? components.region.flatMap { _ in language.script }
    }

    static func languageTag(for track: MediaTrack) -> String? {
        languageTag(track.languageTag) ?? languageTag(track.languageCode) ?? languageTag(track.language)
    }

    private static func languageTag(_ identifier: String?) -> String? {
        guard let identifier else { return nil }
        let parts = identifier.replacingOccurrences(of: "_", with: "-").split(separator: "-", maxSplits: 1)
        let key = TrackLanguage.normalize(parts.first.map(String.init))
        guard TrackLanguage.isKnown(key) else { return nil }
        let code = Locale.LanguageCode(key).identifier(.alpha2) ?? key
        return Locale.canonicalLanguageIdentifier(from: ([code] + parts.dropFirst().map(String.init)).joined(separator: "-"))
    }
}

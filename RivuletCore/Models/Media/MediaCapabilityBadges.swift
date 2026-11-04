import Foundation

enum MediaCapabilityBadges {
    static func detailed(qualityBadges: [String], audioTracks: [AudioTrack], subtitleTracks: [SubtitleTrack]) -> [String] {
        var badges = qualityBadges
        if subtitleTracks.contains(where: { $0.isHearingImpaired }) {
            badges.append("SDH")
        }
        if audioTracks.contains(where: {
            ($0.title ?? $0.extendedTitle ?? "").localizedCaseInsensitiveContains("descri")
        }) {
            badges.append("AD")
        }
        return badges.compactMap { badge in
            let text = badge.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : text
        }
    }
}

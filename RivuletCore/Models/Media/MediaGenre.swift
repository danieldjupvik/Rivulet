// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Foundation

nonisolated enum MediaGenre {
    static func firstNonempty(in genres: [String]) -> String? {
        genres.lazy.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
    }
}

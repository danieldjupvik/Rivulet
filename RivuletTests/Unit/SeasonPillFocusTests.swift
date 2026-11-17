import Testing
import UIKit
@testable import Rivulet

@MainActor
struct SeasonPillFocusTests {
    @Test func episodeEntryTracksSelectedSeasonAndClearsWithoutPills() throws {
        let view = ExpandedDetailContainerView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        view.setSeasonPills(["Season 1", "Season 2", "Season 3"],
                            seasonRefIDs: ["1", "2", "3"], selectedIndex: 1)
        let pills = descendants(of: view).compactMap { $0 as? SeasonPillView }
        let selected = try #require(view.seasonPillsFocusEnvironment)
        let guide = try #require(descendants(of: view).flatMap(\.layoutGuides)
            .compactMap { $0 as? UIFocusGuide }
            .first { $0.preferredFocusEnvironments.first === selected })

        #expect(pills.count == 3)
        #expect(pills.filter(\.canBecomeFocused).count == 1)
        #expect(pills.first(where: \.canBecomeFocused) === selected)
        #expect(guide.isEnabled)

        view.detailsFocusTarget = .pills
        #expect(pills.allSatisfy { $0.canBecomeFocused })
        #expect(guide.isEnabled == false)

        view.selectSeasonPill(2)
        view.detailsFocusTarget = .episodes
        let nextSelected = try #require(view.seasonPillsFocusEnvironment)
        #expect(nextSelected !== selected)
        #expect(pills.filter(\.canBecomeFocused).count == 1)
        #expect(pills.first(where: \.canBecomeFocused) === nextSelected)
        #expect(guide.preferredFocusEnvironments.first === nextSelected)
        #expect(guide.isEnabled)

        view.setSeasonPills(["Season 1"], seasonRefIDs: ["1"], selectedIndex: 0)
        #expect(view.hasSeasonPills == false)
        #expect(guide.isEnabled == false)
        #expect(guide.preferredFocusEnvironments.isEmpty)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    @Test(arguments: ["Season 1", "A much longer season title"])
    func focusKeepsLayoutStableAndResetsAfterResize(title: String) throws {
        let pill = SeasonPillView(frame: .zero)
        pill.configure(label: title, isSelected: true)
        let size = pill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        pill.frame = CGRect(origin: .zero, size: size)
        pill.layoutIfNeeded()
        let background = try #require(pill.subviews.first { !($0 is UILabel) })
        let label = try #require(pill.subviews.compactMap { $0 as? UILabel }.first)
        let originalFrame = pill.frame
        let originalFont = label.font

        pill.setFocused(true)
        #expect(pill.frame == originalFrame)
        #expect(label.font == originalFont)
        #expect(abs(background.frame.width - size.width - 8) < 0.01)
        #expect(abs(background.frame.height - size.height - 8) < 0.01)
        #expect(abs(background.center.y - pill.bounds.midY) < 0.01)
        #expect(label.transform.a == label.transform.d)

        pill.bounds.size.width += 100
        pill.setNeedsLayout()
        pill.layoutIfNeeded()
        #expect(abs(background.frame.width - pill.bounds.width - 8) < 0.01)
        pill.setFocused(false)
        #expect(background.transform == .identity)
        #expect(label.transform == .identity)
        #expect(background.frame == pill.bounds)
    }

    @Test func selectedAppearanceReturnsWhenFocusLeavesAnotherSeason() throws {
        let selected = SeasonPillView(frame: .zero)
        let other = SeasonPillView(frame: .zero)
        selected.configure(label: "Season 1", isSelected: true)
        other.configure(label: "Season 2", isSelected: false)
        let row = UIStackView(arrangedSubviews: [selected, other])
        let selectedBackground = try #require(selected.subviews.first { !($0 is UILabel) })
        let selectedFill = selectedBackground.backgroundColor

        withExtendedLifetime(row) {
            other.setFocused(true)
            #expect(selectedBackground.backgroundColor == .clear)
            other.setFocused(false)
            #expect(selectedBackground.backgroundColor == selectedFill)
        }
    }
}

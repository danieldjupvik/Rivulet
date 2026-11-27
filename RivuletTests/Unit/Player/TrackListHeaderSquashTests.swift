// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

//
//  TrackListHeaderSquashTests.swift
//  RivuletTests
//
//  An overflowing Subtitles panel scrolls its list instead of squashing the
//  header: the list's self-sizing height must not tie the header label's
//  compression resistance. Same tie as `InfoSheetOverflowTests`.
//

import Testing
import XCTest
import UIKit
@testable import Rivulet

@MainActor
struct ToolboxCardHeightTests {
    @Test(arguments: [2, 20])
    func toolboxCardFitsContentUpToTheSharedCap(rowCount: Int) {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let anchor = UIView(frame: CGRect(x: 1500, y: 800, width: 66, height: 66))
        host.addSubview(anchor)
        let rows = (1...rowCount).map {
            CardTrackListView.Row(title: "Track \($0)", subtitle: nil, trackId: $0, isSelected: false)
        }
        let list = CardTrackListView(header: "Subtitles", rows: rows, onSelect: { _ in })
        let panel = PlayerRailPanelView.present(content: list, width: CardTrackListView.menuWidth,
                                               in: host, aboveRail: anchor, towards: anchor)
        defer { panel.dismissPanel() }

        if rowCount == 20 {
            #expect(abs(panel.bounds.height - 600) < 0.5)
        } else {
            #expect(panel.bounds.height > 0 && panel.bounds.height < 600)
        }
    }
}

final class TrackListHeaderSquashTests: XCTestCase {

    func testHeaderKeepsItsHeightWhenTheListOverflowsTheCap() {
        let rows = [CardTrackListView.Row(title: "Off", subtitle: nil, trackId: nil, isSelected: true)]
            + (1...3).map {
                CardTrackListView.Row(title: "English \($0)", subtitle: "English • SRT",
                                      trackId: $0, isSelected: false)
            }
        let stepper = CardStepperConfig(title: "Delay", value: { "0.0s" }, onStep: { _ in })
        let list = CardTrackListView(header: "Subtitles", rows: rows,
                                     steppers: [stepper, stepper], onSelect: { _ in })

        // Capped, not fixed, like the panel (see InfoSheetOverflowTests).
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 480, height: 2000))
        list.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: host.topAnchor),
            list.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            list.widthAnchor.constraint(equalToConstant: 480),
            list.heightAnchor.constraint(lessThanOrEqualToConstant: PlayerRailPanelView.fullContentHeight),
        ])
        host.layoutIfNeeded()

        guard let page = list.subviews.last,
              let header = page.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.text == "Subtitles" }),
              let scroll = page.subviews.compactMap({ $0 as? UIScrollView }).first
        else { return XCTFail("header label or scroll view missing") }

        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height,
                             "fixture must overflow the cap or the test proves nothing")
        XCTAssertEqual(header.frame.height, header.intrinsicContentSize.height, accuracy: 0.5,
                       "header was squashed instead of the list scrolling")
    }
}

final class CardChoiceSubmenuScrollTests: XCTestCase {

    /// Issue #354: with many audio tracks the list is scrolled down when
    /// Enhance Dialogue is chosen. The short submenu then opened scrolled past
    /// its own end, so the card looked empty.
    func testOpeningAChoiceResetsTheScrollOffset() {
        let rows = (1...30).map {
            CardTrackListView.Row(title: "Track \($0)", subtitle: nil, trackId: $0, isSelected: false)
        }
        let choice = CardChoiceConfig(title: "Enhance Dialogue", options: ["Off", "Low", "High"],
                                      selected: { 0 }, onSelect: { _ in })
        let list = CardTrackListView(header: "Audio", rows: rows, choices: [choice], onSelect: { _ in })

        let host = UIView(frame: CGRect(x: 0, y: 0, width: 480, height: 2000))
        list.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: host.topAnchor),
            list.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            list.widthAnchor.constraint(equalToConstant: 480),
            list.heightAnchor.constraint(lessThanOrEqualToConstant: PlayerRailPanelView.fullContentHeight),
        ])
        host.layoutIfNeeded()

        guard let scroll = menuScrollView(in: list),
              let stack = scroll.subviews.compactMap({ $0 as? UIStackView }).first,
              let choiceRow = stack.arrangedSubviews.last as? CardTrackRowButton
        else { return XCTFail("scroll view or choice row missing") }

        scroll.contentOffset = CGPoint(x: 0, y: scroll.contentSize.height - scroll.bounds.height)
        choiceRow.onTap?()
        host.layoutIfNeeded()

        guard let submenuScroll = menuScrollView(in: list),
              let submenuRows = submenuScroll.subviews.compactMap({ $0 as? UIStackView }).first,
              let option = submenuRows.arrangedSubviews.first as? CardTrackRowButton
        else { return XCTFail("submenu scroll view or option missing") }
        XCTAssertEqual(submenuScroll.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertTrue(list.allowsSettingsMenuSwitch(from: option))
    }

    func testLanguageCentersASelectionAlreadyVisibleAtTheBottom() {
        let tracks = (1...12).map { MediaTrack(id: $0, name: "Track \($0)", codec: "srt") }
        let list = CardTrackListView.subtitleMenu(tracks: tracks, selectedTrackId: 5, onTrackId: 5, onSelect: { _ in })
        let host = UIWindow(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        list.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: host.topAnchor),
            list.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            list.widthAnchor.constraint(equalToConstant: 480),
            list.heightAnchor.constraint(equalToConstant: 506),
        ])
        host.layoutIfNeeded()

        guard let parentScroll = menuScrollView(in: list),
              let parentRows = parentScroll.subviews.compactMap({ $0 as? UIStackView }).first,
              let languageRow = parentRows.arrangedSubviews.compactMap({ $0 as? CardTrackRowButton })
                .first(where: { $0.showsChevron })
        else { return XCTFail("Language row missing") }

        languageRow.onTap?()

        guard let languageScroll = menuScrollView(in: list),
              let languageRows = languageScroll.subviews.compactMap({ $0 as? UIStackView }).first,
              let selected = languageRows.arrangedSubviews.compactMap({ $0 as? CardTrackRowButton })
                .first(where: { $0.isChecked })
        else { return XCTFail("Selected track missing") }

        let selectedFrame = selected.convert(selected.bounds, to: languageScroll)
        XCTAssertLessThan(selectedFrame.maxY, languageScroll.bounds.height,
                            "the selected row must already fit in the initial viewport")
        XCTAssertEqual(selectedFrame.midY, languageScroll.bounds.midY, accuracy: 0.5)
        XCTAssertTrue(list.allowsSettingsMenuSwitch(from: selected))
    }

    private func menuScrollView(in list: CardTrackListView) -> UIScrollView? {
        list.subviews.last?.subviews.compactMap { $0 as? UIScrollView }.first
    }
}

@MainActor
struct SubtitleLanguageMenuTests {
    private final class FocusHost: UIViewController {
        weak var initialFocus: UIView?

        override var preferredFocusEnvironments: [UIFocusEnvironment] {
            initialFocus.map { [$0] } ?? super.preferredFocusEnvironments
        }
    }

    @Test(ExclusiveKeyWindowTrait())
    func backMovesFocusFromTheSelectedTrackToParentLanguage() async throws {
        let tracks = (1...20).map { MediaTrack(id: $0, name: "Track \($0)", codec: "srt") }
        let menu = CardTrackListView.subtitleMenu(tracks: tracks, selectedTrackId: 18, onTrackId: 18) { _ in }
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let controller = FocusHost()
        window.rootViewController = controller
        menu.frame = CGRect(x: 100, y: 100, width: 480, height: 506)
        controller.view.addSubview(menu)
        let language = try #require(rows(in: menu).first { $0.showsChevron })
        controller.initialFocus = language
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        controller.view.layoutIfNeeded()

        let focus = try #require(UIFocusSystem.focusSystem(for: menu))
        func expectFocus(on row: CardTrackRowButton, sourceLocation: SourceLocation = #_sourceLocation) async throws {
            let deadline = ContinuousClock.now + .seconds(2)
            while focus.focusedItem !== row, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(5))
            }
            try #require(focus.focusedItem === row, sourceLocation: sourceLocation)
        }

        try await expectFocus(on: language)
        controller.initialFocus = nil
        language.onTap?()
        let selectedTrack = try #require(rows(in: menu).first { $0.row.trackId == 18 })
        try await expectFocus(on: selectedTrack)

        try #require(menu.handleMenuPress())
        let parentLanguage = try #require(rows(in: menu).first { $0.showsChevron })
        try await expectFocus(on: parentLanguage)
    }

    @Test
    func backRestoresTheParentAfterScrollingLanguage() throws {
        let tracks = (1...20).map { MediaTrack(id: $0, name: "Track \($0)", codec: "srt") }
        let menu = CardTrackListView.subtitleMenu(tracks: tracks, selectedTrackId: 18, onTrackId: 18) { _ in }
        let host = UIWindow(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        menu.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(menu)
        NSLayoutConstraint.activate([
            menu.topAnchor.constraint(equalTo: host.topAnchor),
            menu.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            menu.widthAnchor.constraint(equalToConstant: 480),
            menu.heightAnchor.constraint(equalToConstant: 506),
        ])
        host.layoutIfNeeded()
        let language = try #require(rows(in: menu).first { $0.showsChevron })
        language.onTap?()
        host.layoutIfNeeded()
        let scroll = try #require(menu.subviews.last?.subviews.compactMap { $0 as? UIScrollView }.first)
        #expect(scroll.contentOffset.y > 0)
        scroll.setContentOffset(.zero, animated: true)

        #expect(menu.handleMenuPress())
        #expect(scroll.isDescendant(of: menu) == false)
        let parentLanguage = try #require(rows(in: menu).first { $0.showsChevron })
        #expect(menu.preferredFocusEnvironments.first as? UIView === parentLanguage)
        #expect(menu.handleMenuPress() == false)
    }

    @Test
    func choosingLanguageReturnsToParentWithUpdatedSelection() throws {
        let tracks = [
            MediaTrack(id: 1, name: "English", codec: "srt"),
            MediaTrack(id: 2, name: "Finnish", codec: "srt"),
        ]
        var picked: Int?
        let menu = CardTrackListView.subtitleMenu(tracks: tracks, selectedTrackId: nil, onTrackId: 1) { picked = $0 }
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 480, height: 506))
        menu.frame = host.bounds
        host.addSubview(menu)
        host.layoutIfNeeded()
        let language = try #require(rows(in: menu).first { $0.showsChevron })
        language.onTap?()
        let finnish = try #require(rows(in: menu).first { $0.row.trackId == 2 })
        finnish.onTap?()
        #expect(picked == 2)
        #expect(menu.returnToSubtitleMenu(afterSelecting: picked))
        let parentLanguage = try #require(rows(in: menu).first { $0.showsChevron })
        #expect(parentLanguage.row.subtitle == "Finnish")
        #expect(menu.preferredFocusEnvironments.first as? UIView === parentLanguage)
        parentLanguage.onTap?()
        #expect(rows(in: menu).first { $0.row.trackId == 2 }?.isChecked == true)
    }

    private func rows(in view: UIView) -> [CardTrackRowButton] {
        if let row = view as? CardTrackRowButton { return [row] }
        return view.subviews.flatMap(rows)
    }
}

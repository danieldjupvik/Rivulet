// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import SwiftUI
import Testing
import UIKit
@testable import Rivulet

@MainActor
@Suite(.serialized)
struct PlayerRailViewTests {
    @Test
    func toolboxNavigationSkipsUnavailableCardsAndStopsAtTheEnds() {
        let rail = PlayerRailView()
        rail.qualityButton.superview?.semanticContentAttribute = .forceLeftToRight
        rail.setSpeedAvailable(true)
        rail.setFilterAvailable(false)
        rail.setQualityAvailable(true)
        rail.setWatchTogetherAvailable(true)

        #expect(rail.settingsMenuNeighbor(of: rail.speedButton, movingRight: true) === rail.qualityButton)
        #expect(rail.settingsMenuNeighbor(of: rail.qualityButton, movingRight: true) === rail.watchTogetherButton)
        #expect(rail.settingsMenuNeighbor(of: rail.watchTogetherButton, movingRight: false) === rail.qualityButton)
        #expect(rail.settingsMenuNeighbor(of: rail.watchTogetherButton, movingRight: true) == nil)

        rail.setWatchTogetherAvailable(false)
        #expect(rail.settingsMenuNeighbor(of: rail.qualityButton, movingRight: true) == nil)
        #expect(rail.settingsMenuNeighbor(of: rail.qualityButton, movingRight: false) === rail.speedButton)
    }

    @Test
    func returningToThePillsUsesTheRememberedTabWhileItIsAvailable() {
        let rail = PlayerRailView()
        rail.setChaptersAvailable(true)
        rail.rememberPaneEntry(rail.chaptersButton)
        rail.resetFocusMemory()
        #expect(rail.paneEntryPill === rail.chaptersButton)

        rail.setChaptersAvailable(false)
        #expect(rail.paneEntryPill === rail.infoButton)

        rail.setChaptersAvailable(true)
        rail.rememberPaneEntry(nil)
        #expect(rail.paneEntryPill === rail.infoButton)
    }

    @Test
    func openingControlsAfterPaneAutoHideRestoresToolbar() throws {
        let rail = PlayerRailView()
        let toolbar = try #require(rail.audioButton.superview)
        let paneMotion = UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut)
        rail.setPaneLift(100, motion: paneMotion)
        paneMotion.startAnimation()
        paneMotion.stopAnimation(false)
        paneMotion.finishAnimation(at: .end)
        #expect(toolbar.alpha == 0)

        rail.restoreAfterPaneAutoHide()
        #expect(toolbar.alpha == 1)
        #expect(rail.transform.isIdentity)
    }

    @Test
    func paneTimeoutWaitsForPlaybackAndContactAndKeepsDetailsOpen() {
        let vm = UniversalPlayerViewModel(metadata: PlexMetadata(type: "movie"),
                                          serverURL: "http://plex.local", authToken: "t")
        defer { vm.updatePlaybackState(.idle) }
        for state in [UniversalPlaybackState.loading, .ready, .buffering] {
            vm.updatePlaybackState(state)
            #expect(vm.paneIdleAction(isDetails: false) == .postpone)
        }

        vm.updatePlaybackState(.playing)
        vm.hasRemoteContact = { true }
        #expect(vm.paneIdleAction(isDetails: false) == .postpone)
        vm.hasRemoteContact = { false }
        #expect(vm.paneIdleAction(isDetails: false) == .hideControls)
        #expect(vm.paneIdleAction(isDetails: true) == .keepOpen)

        vm.updatePlaybackState(.paused)
        #expect(vm.paneIdleAction(isDetails: false) == .closePane)
        #expect(vm.paneIdleAction(isDetails: true) == .keepOpen)
    }

    @Test
    func autoHideBackGraceIsSingleUseAndClearsOnRevealOrPause() {
        let vm = UniversalPlayerViewModel(metadata: PlexMetadata(type: "movie"),
                                          serverURL: "http://plex.local", authToken: "t")
        defer { vm.updatePlaybackState(.idle) }
        vm.updatePlaybackState(.playing)
        vm.showControls = false
        #expect(!vm.consumeAutoHideBackGrace(now: 10))

        vm.showControls = true
        vm.isRailPanelOpen = true
        vm.autoHideControls(now: 10)
        #expect(!vm.showControls)
        #expect(vm.consumeAutoHideBackGrace(now: 10.4))
        #expect(!vm.consumeAutoHideBackGrace(now: 10.45))
        vm.isRailPanelOpen = false

        vm.showControls = true
        vm.autoHideControls(now: 20)
        #expect(!vm.consumeAutoHideBackGrace(now: 20.5))

        vm.showControls = true
        vm.autoHideControls(now: 30)
        vm.showControls = true
        vm.showControls = false
        #expect(!vm.consumeAutoHideBackGrace(now: 30.2))

        vm.showControls = true
        vm.autoHideControls(now: 40)
        vm.updatePlaybackState(.paused)
        #expect(!vm.consumeAutoHideBackGrace(now: 40.2))
    }

    @Test
    func systemDismissConsumesBackGraceAfterAutoHide() {
        let vm = UniversalPlayerViewModel(metadata: PlexMetadata(type: "movie"),
                                          serverURL: "http://plex.local", authToken: "t")
        let controller = PlayerContainerViewController(rootView: Color.black, viewModel: vm,
                                                       inputCoordinator: PlaybackInputCoordinator())
        defer { vm.updatePlaybackState(.idle) }
        vm.updatePlaybackState(.playing)
        let now = CACurrentMediaTime()
        vm.autoHideControls(now: now)

        controller.dismiss(animated: false)

        #expect(!vm.consumeAutoHideBackGrace(now: now))
    }

    @Test(ExclusiveKeyWindowTrait(), arguments: [false, true])
    func downOpensTheRememberedPaneFromContentOrHiddenScrubber(_ useHiddenScrubber: Bool) async throws {
        var metadata = PlexMetadata(type: "movie")
        metadata.Chapter = [
            PlexChapter(id: nil, tag: "Opening", index: nil, startTimeOffset: 0, endTimeOffset: nil, thumb: nil),
        ]
        let vm = UniversalPlayerViewModel(metadata: metadata, serverURL: "http://plex.local", authToken: "t")
        vm.showControls = false
        vm.updatePlaybackState(.playing)
        let controller = PlayerContainerViewController(rootView: Color.black, viewModel: vm,
                                                       inputCoordinator: PlaybackInputCoordinator())
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
            vm.updatePlaybackState(.idle)
        }
        controller.view.layoutIfNeeded()
        let proxy = try #require(controller.view.subviews.compactMap { $0 as? ScrubberFocusProxyView }.first)
        let rail = try #require(controller.view.subviews.compactMap { $0 as? PlayerRailView }.first)
        let focus = try #require(UIFocusSystem.focusSystem(for: controller.view))
        let content = try #require(controller.preferredFocusEnvironments.first as? UIView)
        try await waitForPlayerCondition { focus.focusedItem === content }
        rail.setChaptersAvailable(true)
        rail.rememberPaneEntry(rail.chaptersButton)
        vm.showControlsTemporarily()
        try await waitForPlayerCondition { proxy.canBecomeFocused && rail.alpha == 1 }
        let swipe = try #require(controller.view.gestureRecognizers?.compactMap { $0 as? UISwipeGestureRecognizer }
            .first { $0.direction == .down && $0.delegate is DirectionalInputBinding })
        let binding = try #require(swipe.delegate as? DirectionalInputBinding)
        if useHiddenScrubber {
            rail.setFocusLanding(proxy)
            vm.enterControlsFocus()
            controller.setNeedsFocusUpdate()
            controller.updateFocusIfNeeded()
            try await waitForPlayerCondition { focus.focusedItem === proxy }
            #expect(binding.gestureRecognizerShouldBegin(swipe) == false)
            vm.showControls = false
            try #require(focus.focusedItem === proxy)
        } else {
            try #require(vm.showControls)
            try #require(focus.focusedItem === content)
        }
        try #require(binding.gestureRecognizerShouldBegin(swipe))
        binding.handleSwipe(swipe)

        let panel = try #require(controller.view.subviews.compactMap { $0 as? PlayerRailPanelView }.first)
        defer { panel.dismissPanel() }
        #expect(panel.subviews.contains { $0 is PlayerCardRowView })
        #expect(vm.showControls)
        try await waitForPlayerCondition { focus.focusedItem === rail.chaptersButton }
    }

    private func waitForPlayerCondition(timeout: Duration = .seconds(2),
                                        sourceLocation: SourceLocation = #_sourceLocation,
                                        _ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(predicate(), sourceLocation: sourceLocation)
    }

    enum DescriptionOrigin: CaseIterable {
        case info, insights, pauseInsights
    }

    @Test(ExclusiveKeyWindowTrait(), arguments: DescriptionOrigin.allCases)
    func fullDescriptionTakesFocusAndYieldsToBackOrUpNext(_ origin: DescriptionOrigin) async throws {
        var metadata = PlexMetadata(type: "movie")
        metadata.summary = String(repeating: "A long description for the Info pane. ", count: 20)
        let vm = UniversalPlayerViewModel(metadata: metadata, serverURL: "http://plex.local", authToken: "t")
        vm.showControls = false
        let paused = origin == .pauseInsights
        vm.updatePlaybackState(paused ? .paused : .playing)
        let controller = FocusTestPlayer(rootView: Color.black, viewModel: vm,
                                         inputCoordinator: PlaybackInputCoordinator())
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
            vm.updatePlaybackState(.idle)
        }

        let focus = try #require(UIFocusSystem.focusSystem(for: controller.view))
        let rail = try #require(controller.view.subviews.compactMap { $0 as? PlayerRailView }.first)
        let content = try #require(controller.preferredFocusEnvironments.first as? UIView)
        try await waitForPlayerCondition { focus.focusedItem === content }
        let pane: UIView
        if paused {
            let pauseScreen = try #require(controller.view.subviews.compactMap { $0 as? PauseScreenView }.first)
            try await waitForPlayerCondition(timeout: .seconds(12)) { pauseScreen.isShowing }
            vm.debugSetInsightsTrivia(try #require(ScrubStatesProbe.fixtureTrivia))
            try await waitForPlayerCondition { pauseScreen.showsInsightsHint }
            controller.debugContentVertical(up: false)
            pane = try #require(controller.view.subviews.compactMap { $0 as? PauseInsightsView }.first)
        } else {
            vm.showControlsTemporarily()
            try await waitForPlayerCondition { rail.alpha == 1 }
            if origin == .insights {
                vm.debugSetInsightsTrivia(try #require(ScrubStatesProbe.fixtureTrivia))
                try await waitForPlayerCondition { !rail.insightsButton.isHidden }
                rail.rememberPaneEntry(rail.insightsButton)
            }
            let swipe = try #require(controller.view.gestureRecognizers?.compactMap { $0 as? UISwipeGestureRecognizer }
                .first { $0.direction == .down && $0.delegate is DirectionalInputBinding })
            let binding = try #require(swipe.delegate as? DirectionalInputBinding)
            try #require(binding.gestureRecognizerShouldBegin(swipe))
            binding.handleSwipe(swipe)
            pane = try #require(controller.view.subviews.compactMap { $0 as? PlayerRailPanelView }.first)
        }

        defer { (pane as? PlayerRailPanelView)?.dismissPanel() }
        let summary: PlayerSummaryButton
        if origin != .info {
            let insights = try #require((pane as? PauseInsightsView)?.insights
                                        ?? pane.subviews.compactMap { $0 as? InsightsPanelContainerView }.first)
            let person = MediaPerson(id: "fixture", name: "Actor", role: nil, imageURL: nil,
                                     providerID: "focus-test-fixture")
            insights.crossfadeToActor(person)
            let actor = try #require(insights.actorView)
            try await waitForPlayerCondition { actor.detail != nil }
            actor.populate(PersonDetail(id: person.id, name: person.name, biography: metadata.summary,
                                        portraitURL: nil, movies: [], shows: []))
            summary = try #require(actor.preferredFocusEnvironments.first as? PlayerSummaryButton)
        } else {
            let card = try #require(pane.subviews.compactMap { $0 as? PlayerInfoCardView }.first)
            summary = try #require(card.subviews.compactMap { $0 as? PlayerSummaryButton }.first)
        }
        try await waitForPlayerCondition {
            summary.canBecomeFocused && (pane.layer.presentation()?.affineTransform().ty ?? 0) < 1
        }
        controller.focusTarget = summary
        controller.setNeedsFocusUpdate()
        controller.updateFocusIfNeeded()
        try await waitForPlayerCondition { focus.focusedItem === summary }
        controller.focusTarget = nil
        let expand = try #require(summary.onPress)
        expand()

        let overlay = try #require(controller.view.subviews.compactMap { $0 as? PlayerDescriptionOverlayView }.first)
        try await waitForPlayerCondition { (focus.focusedItem as? UIView)?.isDescendant(of: overlay) == true }
        #expect(vm.showControls == !paused)
        #expect(vm.isRailPanelOpen == !paused)
        #expect(vm.controlsOwnRemoteInput)
        #expect(pane.alpha == 1)

        if origin == .insights {
            vm.postVideoState = .showingEpisodeSummary
            try await waitForPlayerCondition {
                guard let upNext = controller.view.subviews.compactMap({ $0 as? PostVideoOverlayView }).first,
                      let focused = focus.focusedItem as? UIView else { return false }
                return overlay.superview == nil && pane.superview == nil && focused.isDescendant(of: upNext)
            }
            #expect(vm.isRailPanelOpen == false)
        } else {
            controller.dismiss(animated: false)
            try await waitForPlayerCondition { focus.focusedItem === summary }
            try #require(overlay.superview === controller.view)
            if origin == .info {
                controller.focusTarget = rail.infoButton
                controller.setNeedsFocusUpdate()
                controller.updateFocusIfNeeded()
                try #require(focus.focusedItem === rail.infoButton)
                controller.focusTarget = nil
            }
            try await waitForPlayerCondition { overlay.superview == nil }
            let expectedFocus: UIView = origin == .info ? rail.infoButton : summary
            #expect(focus.focusedItem === expectedFocus)
            #expect(vm.showControls == !paused)
            #expect(vm.isRailPanelOpen == !paused)
            #expect(pane.superview === controller.view)
            if paused {
                #expect(vm.pausePresentation == .info)
                #expect(vm.controlsOwnRemoteInput == false)
            }
        }
    }

    @Test
    func closingUpNextRearmsControlsAutoHide() async throws {
        let vm = UniversalPlayerViewModel(metadata: PlexMetadata(type: "episode"),
                                          serverURL: "http://plex.local", authToken: "t")
        vm.updatePlaybackState(.playing)
        defer { vm.updatePlaybackState(.idle) }
        vm.autoHideControls()
        vm.postVideoState = .loading
        vm.showControls = true
        vm.closePostVideo()

        #expect(vm.postVideoState == .hidden)
        #expect(vm.showControls)
        try await waitForPlayerCondition(timeout: .seconds(UniversalPlayerViewModel.controlsHideDelay + 2)) {
            !vm.showControls
        }
    }

    @Test(ExclusiveKeyWindowTrait(), arguments: [false, true])
    func clockLabelsHoldThroughTheTimelineFade(_ opensPane: Bool) async throws {
        let vm = UniversalPlayerViewModel(metadata: PlexMetadata(type: "movie"),
                                          serverURL: "http://plex.local", authToken: "t")
        vm.updatePlaybackState(.playing)
        let controller = PlayerContainerViewController(rootView: Color.black, viewModel: vm,
                                                       inputCoordinator: PlaybackInputCoordinator())
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
            vm.updatePlaybackState(.idle)
        }

        let bar = try #require(controller.view.subviews.compactMap { $0 as? PlayerProgressBarView }.first)
        try await waitForPlayerCondition { bar.alpha == 1 && (bar.layer.presentation()?.opacity ?? 1) >= 0.99 }
        bar.setShowsClockTimes(true)

        if opensPane {
            controller.debugPresentPane("info")
        } else {
            vm.showControls = false
        }
        try await waitForPlayerCondition { bar.alpha == 0 }
        #expect(bar.showsClockTimes)
        try await waitForPlayerCondition { bar.showsClockTimes == false }

        if opensPane {
            let panel = try #require(controller.view.subviews.compactMap { $0 as? PlayerRailPanelView }.first)
            panel.dismissPanel()
        } else {
            vm.showControlsTemporarily()
        }
        try await waitForPlayerCondition { bar.alpha == 1 }
        #expect(bar.showsClockTimes == false)
    }

    private final class FocusTestPlayer: PlayerContainerViewController {
        weak var focusTarget: UIView?

        override var preferredFocusEnvironments: [UIFocusEnvironment] {
            if let focusTarget { return [focusTarget] }
            return super.preferredFocusEnvironments
        }
    }
}

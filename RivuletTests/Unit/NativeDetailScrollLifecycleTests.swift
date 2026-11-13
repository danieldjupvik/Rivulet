import Testing
import UIKit
@testable import Rivulet

@Suite(.serialized)
@MainActor
struct NativeDetailScrollLifecycleTests {
    private func makeView() throws -> (BelowFoldCollectionView, FocusScrollControlledCollectionView) {
        let view = BelowFoldCollectionView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        view.layoutIfNeeded()
        let collection = try #require(view.subviews.compactMap { $0 as? FocusScrollControlledCollectionView }.first)
        return (view, collection)
    }

    @Test func customSlideRestoresNativeScrollingOnCompletion() async throws {
        let (view, collection) = try makeView()
        #expect(collection.isScrollEnabled)
        var completed = false
        view.slideToDetailsTop(animated: true) { completed = true }
        #expect(collection.isScrollEnabled == false)
        let deadline = ContinuousClock.now + .seconds(2)
        while !completed, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(completed)
        #expect(collection.isScrollEnabled)
    }

    @Test func resetCancelsCustomSlideAndRestoresNativeScrolling() async throws {
        let (view, collection) = try makeView()
        var staleCompletion = false
        view.slideToDetailsTop(animated: true) { staleCompletion = true }
        #expect(collection.isScrollEnabled == false)
        view.resetScroll()
        #expect(collection.isScrollEnabled)
        let rest = collection.contentOffset
        try await Task.sleep(for: .seconds(1))
        #expect(staleCompletion == false)
        #expect(collection.contentOffset == rest)
    }

    @Test func immediateReturnSupersedesCustomSlide() async throws {
        let (view, collection) = try makeView()
        var staleCompletion = false
        var returned = false
        view.slideToDetailsTop(animated: true) { staleCompletion = true }
        view.slideToHeroRest(animated: false) { returned = true }
        #expect(returned)
        #expect(collection.isScrollEnabled)
        let rest = collection.contentOffset
        try await Task.sleep(for: .seconds(1))
        #expect(staleCompletion == false)
        #expect(collection.contentOffset == rest)
    }
}

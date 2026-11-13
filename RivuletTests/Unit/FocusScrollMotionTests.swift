import Testing
import XCTest
@testable import Rivulet

final class FocusScrollMotionTests: XCTestCase {
    func test_minimalOffset_keepsEdgeInsetAndOnlyMovesWhenNeeded() {
        let row = CGRect(x: 0, y: 1500, width: 260, height: 430)
        XCTAssertEqual(FocusScrollMotion.minimalOffset(revealing: row, from: 0, height: 1080), 1500 + 430 - 1080 + 180)
        XCTAssertEqual(FocusScrollMotion.minimalOffset(revealing: row, from: 1100, height: 1080), 1100)
        XCTAssertEqual(FocusScrollMotion.minimalOffset(revealing: row, from: 2000, height: 1080), 1500 - 180)
    }
}

struct FocusScrollFollowerTests {
    @Test(arguments: [CGFloat(515), 982.5, -515])
    func settlesExactlyDespiteRoundedDisplay(target: CGFloat) {
        var motion = FocusScrollMotion.Follower(position: 0)
        var roundedFeedback = motion
        var done = false
        var frames = 0
        while !done && frames < 120 {
            done = motion.advance(toward: target, elapsed: 1 / 59.94, viewport: 1080)
            let rounded = (roundedFeedback.position * 2).rounded() / 2
            roundedFeedback.translate(by: rounded - roundedFeedback.position)
            _ = roundedFeedback.advance(toward: target, elapsed: 1 / 59.94, viewport: 1080)
            frames += 1
        }
        #expect(done)
        #expect(motion.position == target)
        #expect(abs(roundedFeedback.position - target) > 1)
        #expect(frames > 30 && frames < 90)
    }

    @Test(arguments: [CGFloat(1), -1])
    func reversalBrakesBeforeChangingDirection(direction: CGFloat) {
        var motion = FocusScrollMotion.Follower(position: 0)
        for _ in 0..<4 {
            _ = motion.advance(toward: 500 * direction, elapsed: 0.016, viewport: 1080)
        }
        #expect(abs(motion.position - 100 * direction) < 0.0001)
        _ = motion.advance(toward: -500 * direction, elapsed: 0.016, viewport: 1080)
        #expect(abs(motion.position - 130 * direction) < 0.0001)
        var done = false
        for _ in 0..<120 {
            done = motion.advance(toward: -500 * direction, elapsed: 0.016, viewport: 1080)
            if done { break }
        }
        #expect(done)
        #expect(motion.position == -500 * direction)
    }

    @Test
    func fartherRetargetContinuesFromTheExistingDisplacement() {
        var motion = FocusScrollMotion.Follower(position: 0)
        for _ in 0..<4 {
            _ = motion.advance(toward: 500, elapsed: 0.016, viewport: 1080)
        }
        _ = motion.advance(toward: 1000, elapsed: 0.016, viewport: 1080)
        #expect(abs(motion.position - 150) < 0.0001)
    }

    @Test(arguments: [CGFloat(1), -1])
    func distantTargetWaitsForOneViewportOfTravel(direction: CGFloat) {
        var motion = FocusScrollMotion.Follower(position: 0)
        for frame in 1...14 {
            _ = motion.advance(toward: 10_000 * direction, elapsed: 0.016, viewport: 1000)
            #expect(abs(motion.position - CGFloat(frame * (frame + 1) * 5) * direction) < 0.0001)
        }
        _ = motion.advance(toward: 10_000 * direction, elapsed: 0.016, viewport: 1000)
        #expect(abs(motion.position - 8150 * direction) < 0.0001)
    }

    @Test
    func delayedCallbackIsOneAccelerationStep() {
        var motion = FocusScrollMotion.Follower(position: 0)
        _ = motion.advance(toward: 500, elapsed: 0.050, viewport: 1080)
        #expect(motion.position == 10)
        _ = motion.advance(toward: 500, elapsed: 0.100, viewport: 1080)
        #expect(motion.position == 30)
    }

    @Test
    func elapsedTimeUsesWholeMillisecondsWithoutAFrameClamp() {
        var first = FocusScrollMotion.Follower(position: 0)
        var second = first
        _ = first.advance(toward: 10, elapsed: 0.0161, viewport: 1080)
        _ = second.advance(toward: 10, elapsed: 0.0169, viewport: 1080)
        #expect(first.position == second.position)
        var delayed = FocusScrollMotion.Follower(position: 0)
        _ = delayed.advance(toward: 10, elapsed: 0.100, viewport: 1080)
        #expect(delayed.position > 4.8 && delayed.position < 4.9)
        var submillisecond = FocusScrollMotion.Follower(position: 0)
        let done = submillisecond.advance(toward: 10, elapsed: 0.0009, viewport: 1080)
        #expect(!done)
        #expect(submillisecond.position == 0)
    }

    @Test
    func layoutTranslationPreservesTheMotionRelativeToItsTarget() {
        var original = FocusScrollMotion.Follower(position: 0)
        for _ in 0..<8 {
            _ = original.advance(toward: 5000, elapsed: 0.016, viewport: 1000)
        }
        var shifted = original
        shifted.translate(by: 350)
        for _ in 0..<120 {
            let done = original.advance(toward: 5000, elapsed: 0.016, viewport: 1000)
            let shiftedDone = shifted.advance(toward: 5350, elapsed: 0.016, viewport: 1000)
            #expect(abs(shifted.position - original.position - 350) < 0.0001)
            #expect(done == shiftedDone)
            if done { break }
        }
        #expect(shifted.position == 5350)
    }

    @Test
    func completionSnapsOnlyInsideTheHalfPointThreshold() {
        var motion = FocusScrollMotion.Follower(position: 0)
        let firstDone = motion.advance(toward: 0.5, elapsed: 0.016, viewport: 1080)
        let secondDone = motion.advance(toward: 0.5, elapsed: 0.016, viewport: 1080)
        #expect(!firstDone)
        #expect(secondDone)
        #expect(motion.position == 0.5)
    }
}

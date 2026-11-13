import Foundation

@main
struct PrecisionProbe {
    static func main() {
        for target: CGFloat in [515, 982.5, -515] {
            for roundTrip in [true, false] {
                var motion = FocusScrollMotion.Follower(position: 0)
                var displayed: CGFloat = 0
                var done = false
                var frames = 0
                for _ in 0..<600 {
                    if roundTrip { motion.translate(by: displayed - motion.position) }
                    done = motion.advance(toward: target, elapsed: 1.0 / 59.94, viewport: 1080)
                    displayed = (motion.position * 2).rounded() / 2
                    frames += 1
                    if done { break }
                }
                print("target=\(target) roundedFeedback=\(roundTrip) frames=\(frames) displayed=\(displayed) done=\(done)")
                precondition(roundTrip ? !done : done && displayed == target)
            }
        }
    }
}

// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import UIKit
import UIKit.UIGestureRecognizerSubclass

final class RemoteContactGestureRecognizer: UIGestureRecognizer {
    private var contacts = Set<UITouch>()
    private var lastContactUpdate: CFTimeInterval = 0

    var hasReliableContact: Bool {
        isEnabled && view?.window != nil && !contacts.isEmpty
            && CACurrentMediaTime() - lastContactUpdate < 30
    }

    init() {
        super.init(target: nil, action: nil)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        allowedPressTypes = []
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if !hasReliableContact { clearContact() }
        contacts.formUnion(touches)
        lastContactUpdate = CACurrentMediaTime()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if !contacts.isDisjoint(with: touches) { lastContactUpdate = CACurrentMediaTime() }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        contacts.subtract(touches)
        if contacts.isEmpty { state = .failed }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        clearContact()
        state = .failed
    }

    override func reset() {
        super.reset()
        clearContact()
    }

    func clearContact() {
        contacts.removeAll()
        lastContactUpdate = 0
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

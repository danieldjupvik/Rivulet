// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import UIKit

final class DetailBackdropBlurView: UIView {
    private let effectView = UIVisualEffectView(effect: nil)
    private var blurAnimator: UIViewPropertyAnimator?

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isHidden = true
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(effectView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("DetailBackdropBlurView is not Storyboard-backed") }

    deinit { blurAnimator?.stopAnimation(true) }

    func update(progress: CGFloat) {
        let p = max(0, min(1, progress))
        isHidden = p == 0
        animatorIfNeeded().fractionComplete = min(0.999, max(0.001, p))
    }

    private func animatorIfNeeded() -> UIViewPropertyAnimator {
        if let blurAnimator { return blurAnimator }
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
            self?.effectView.effect = UIBlurEffect(style: .dark)
        }
        animator.pausesOnCompletion = true
        animator.startAnimation()
        animator.pauseAnimation()
        blurAnimator = animator
        return animator
    }
}

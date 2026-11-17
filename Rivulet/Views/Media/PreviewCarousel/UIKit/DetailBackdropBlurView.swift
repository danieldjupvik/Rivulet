// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import UIKit

final class DetailBackdropBlurView: UIView {
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let effectMask = UIView()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isHidden = true
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(effectView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("DetailBackdropBlurView is not Storyboard-backed") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if effectMask.frame != effectView.bounds { applyMask() }
    }

    func update(progress: CGFloat) {
        let p = max(0, min(1, progress))
        isHidden = p == 0
        effectMask.backgroundColor = UIColor.white.withAlphaComponent(p)
        applyMask()
    }

    private func applyMask() {
        effectMask.frame = effectView.bounds
        // UIKit copies effect-view masks, so reassign after changing their fill or bounds.
        effectView.mask = effectMask
    }
}

// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import UIKit

final class ArtworkScrimView: UIView {
    private let tint = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        tint.locations = [0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1]
        layer.addSublayer(tint)
        configure(color: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tint.frame = bounds
        CATransaction.commit()
    }

    func configure(color: UIColor?) {
        let color = color ?? UIColor(white: 0.12, alpha: 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tint.colors = [CGFloat(0), 0.03, 0.06, 0.14, 0.27, 0.46, 0.65, 0.82, 0.92, 0.97, 1].map {
            color.withAlphaComponent($0).cgColor
        }
        CATransaction.commit()
    }

}

// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import UIKit

final class ArtworkScrimView: UIView {
    private let tint = CAGradientLayer()
    private let darkening = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        tint.locations = [0.66, 0.71, 0.77, 0.81, 0.85, 0.9, 0.94, 1]
        darkening.locations = [0.53, 0.59, 0.65, 0.7, 0.74, 0.79, 0.83, 0.87, 0.91, 1]
        darkening.colors = [CGFloat(0), 0.0256, 0.0832, 0.1664, 0.2688, 0.3712, 0.4736, 0.5568, 0.6144, 0.64].map {
            UIColor(white: 40 / 255, alpha: $0).cgColor
        }
        for gradient in [tint, darkening] {
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 0, y: 1)
            layer.addSublayer(gradient)
        }
        configure(color: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tint.frame = bounds
        darkening.frame = bounds
        CATransaction.commit()
    }

    func configure(color: UIColor?) {
        let color = color ?? .black
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tint.colors = [CGFloat(0), 0.05, 0.18, 0.35, 0.55, 0.72, 0.86, 0.9].map {
            color.withAlphaComponent($0).cgColor
        }
        CATransaction.commit()
    }
}

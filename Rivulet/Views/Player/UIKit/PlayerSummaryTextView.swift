// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import UIKit

final class PlayerSummaryTextView: UIView {
    private let textView = UITextView(usingTextLayoutManager: false)
    private let moreLabel = UILabel()
    private let lines: Int
    private lazy var moreLeft = moreLabel.leftAnchor.constraint(equalTo: textView.leftAnchor, constant: 5)
    private lazy var moreRight = moreLabel.rightAnchor.constraint(equalTo: textView.rightAnchor, constant: -5)
    private lazy var moreBaseline = moreLabel.firstBaselineAnchor.constraint(equalTo: textView.topAnchor)
    private var measuredSize: CGSize?
    private(set) var isTextTruncated = false

    init(text: String, lines: Int) {
        self.lines = lines
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        textView.backgroundColor = .clear
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.isUserInteractionEnabled = false
        textView.isAccessibilityElement = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.heightTracksTextView = false
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textColor = .secondaryLabel
        textView.adjustsFontForContentSizeCategory = true
        moreLabel.text = String(localized: "More").localizedUppercase
        moreLabel.textColor = .label
        moreLabel.adjustsFontForContentSizeCategory = true
        moreLabel.isAccessibilityElement = false
        moreLabel.isHidden = true
        [textView, moreLabel].forEach {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            moreBaseline,
            moreRight,
        ])
        updateTypography()
        setText(text)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: PlayerSummaryTextView, _: UITraitCollection) in
            view.updateTypography()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setText(_ text: String) {
        textView.text = text
        measuredSize = nil
        setNeedsLayout()
    }

    private func updateTypography() {
        let font = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traitCollection)
        textView.font = font
        moreLabel.font = .systemFont(ofSize: font.pointSize, weight: .semibold)
        let lineLimit = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? min(lines, 2) : lines
        textView.textContainer.maximumNumberOfLines = lineLimit
        measuredSize = nil
        textView.invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, measuredSize != bounds.size else { return }
        measuredSize = bounds.size
        let container = textView.textContainer
        let manager = textView.layoutManager
        container.size = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
        textView.layer.mask = nil
        manager.ensureLayout(for: container)
        let glyphs = manager.glyphRange(for: container)
        let lastGlyph = NSMaxRange(glyphs) - 1
        isTextTruncated = glyphs.length > 0 && NSMaxRange(glyphs) < manager.numberOfGlyphs
        moreLabel.isHidden = !isTextTruncated
        guard isTextTruncated else { return }
        var lineGlyphs = NSRange()
        let line = manager.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: &lineGlyphs)
        let rtl = isRightToLeft(onLineStartingAt: lineGlyphs.location, visibleGlyphs: glyphs)
        moreBaseline.constant = line.minY + manager.location(forGlyphAt: lineGlyphs.location).y
        if moreLeft.isActive != rtl {
            NSLayoutConstraint.deactivate([rtl ? moreRight : moreLeft])
            NSLayoutConstraint.activate([rtl ? moreLeft : moreRight])
        }
        updateTrailingFade(on: line, rtl: rtl, reservedWidth: moreLabel.intrinsicContentSize.width + 10)
    }

    private func isRightToLeft(onLineStartingAt glyph: Int, visibleGlyphs: NSRange) -> Bool {
        let manager = textView.layoutManager
        let character = manager.characterIndexForGlyph(at: glyph)
        let paragraph = (textView.textStorage.string as NSString).paragraphRange(for: NSRange(location: character, length: 0))
        let paragraphGlyphs = manager.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
        let glyphs = NSIntersectionRange(paragraphGlyphs, visibleGlyphs)
        var levels = [UInt8](repeating: 0, count: glyphs.length)
        let count = levels.withUnsafeMutableBufferPointer {
            manager.getGlyphs(in: glyphs, glyphs: nil, properties: nil, characterIndexes: nil, bidiLevels: $0.baseAddress)
        }
        return levels.prefix(count).min().map { $0 % 2 == 1 } ?? false
    }

    private func updateTrailingFade(on line: CGRect, rtl: Bool, reservedWidth: CGFloat) {
        let reservedWidth = min(reservedWidth, bounds.width)
        let fadeWidth = min(2 * line.height, bounds.width - reservedWidth)
        let fadeX = rtl ? reservedWidth : bounds.width - reservedWidth - fadeWidth
        let mask = CALayer()
        mask.frame = textView.bounds
        let opaque = CAShapeLayer()
        let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: bounds.width, height: line.minY))
        let solidX = rtl ? fadeX + fadeWidth : 0
        let solidWidth = rtl ? bounds.width - solidX : fadeX
        path.append(UIBezierPath(rect: CGRect(x: solidX, y: line.minY, width: solidWidth, height: line.height)))
        opaque.path = path.cgPath
        opaque.fillColor = UIColor.black.cgColor
        mask.addSublayer(opaque)
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(x: fadeX, y: line.minY, width: fadeWidth, height: line.height)
        gradient.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        gradient.startPoint = CGPoint(x: rtl ? 1 : 0, y: 0.5)
        gradient.endPoint = CGPoint(x: rtl ? 0 : 1, y: 0.5)
        mask.addSublayer(gradient)
        textView.layer.mask = mask
    }
}

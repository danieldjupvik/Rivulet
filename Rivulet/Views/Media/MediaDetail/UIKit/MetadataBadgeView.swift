import UIKit

final class MetadataBadgeView: UIView {
    private let label = UILabel()

    var text: String? {
        get { label.text }
        set { label.text = newValue }
    }

    init(_ text: String? = nil, relativeTo font: UIFont, color: UIColor, filled: Bool = false) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let height = ceil(font.capHeight * 1.2)
        let padding = height * 0.36
        layer.cornerRadius = height * 0.18
        layer.cornerCurve = .continuous
        layer.borderWidth = filled ? 0 : height * 0.07
        layer.borderColor = color.cgColor
        backgroundColor = filled ? color : .clear

        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: font.pointSize * 0.68, weight: .bold)
        label.textColor = filled ? .black : color
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

import AppKit

extension AppDelegate {
    func productBackgroundColor() -> NSColor {
        NSColor.windowBackgroundColor
    }

    func productCardColor() -> NSColor {
        NSColor.controlBackgroundColor
    }

    func separator() -> NSView {
        let rule = NSBox()
        rule.boxType = .separator
        return rule
    }

    func symbolCircle(_ symbol: String, tone: Tone, size: CGFloat) -> NSView {
        let colors = toneColors(tone)
        let box = RoundedView(fill: colors.background, stroke: nil, radius: size / 2)
        box.widthAnchor.constraint(equalToConstant: size).isActive = true
        box.heightAnchor.constraint(equalToConstant: size).isActive = true

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.contentTintColor = colors.foreground
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        box.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: size * 0.52),
            imageView.heightAnchor.constraint(equalToConstant: size * 0.52)
        ])
        return box
    }

    func spacer(width: CGFloat? = nil) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if let width {
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
        }
        return view
    }

    func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.lineBreakMode = .byWordWrapping
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func toneColors(_ tone: Tone) -> (background: NSColor, foreground: NSColor) {
        switch tone {
        case .good:
            return (NSColor.systemGreen.withAlphaComponent(0.16), NSColor.systemGreen)
        case .warning:
            return (NSColor.systemOrange.withAlphaComponent(0.17), NSColor.systemOrange)
        case .danger:
            return (NSColor.systemRed.withAlphaComponent(0.15), NSColor.systemRed)
        case .blue:
            return (NSColor.controlAccentColor.withAlphaComponent(0.16), NSColor.controlAccentColor)
        case .neutral:
            return (NSColor.secondaryLabelColor.withAlphaComponent(0.12), NSColor.secondaryLabelColor)
        }
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

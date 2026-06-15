import AppKit

final class RoundedView: NSView {
    private var fillColor: NSColor
    private var strokeColor: NSColor?
    private let radius: CGFloat

    init(fill: NSColor, stroke: NSColor? = nil, radius: CGFloat = 8) {
        self.fillColor = fill
        self.strokeColor = stroke
        self.radius = radius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        applyLayer()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayer()
    }

    func update(fill: NSColor, stroke: NSColor? = nil) {
        fillColor = fill
        strokeColor = stroke
        applyLayer()
    }

    private func applyLayer() {
        layer?.cornerRadius = radius
        layer?.masksToBounds = true
        layer?.backgroundColor = layerColor(fillColor)
        if let strokeColor {
            layer?.borderWidth = 1
            layer?.borderColor = layerColor(strokeColor)
        } else {
            layer?.borderWidth = 0
            layer?.borderColor = nil
        }
    }

    private func layerColor(_ color: NSColor) -> CGColor {
        color.usingColorSpace(.deviceRGB)?.cgColor ?? color.cgColor
    }
}

import AppKit

extension AppDelegate {
    @objc func showAbout() {
        if let existing = aboutWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About".localized
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentView = aboutRootView()
        aboutWindow = window

        if let content = window.contentView {
            content.layoutSubtreeIfNeeded()
            let target = content.fittingSize
            var frame = window.frame
            frame.size.height = max(target.height, 1)
            frame.size.width = max(target.width, 440)
            window.setFrame(frame, display: true)
        }
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func aboutVersionLine() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    func aboutRootView() -> NSView {
        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 14
        content.alignment = .leading
        content.edgeInsets = NSEdgeInsets(top: 24, left: 26, bottom: 24, right: 26)
        content.translatesAutoresizingMaskIntoConstraints = false

        // Header
        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.spacing = 12
        titleRow.alignment = .centerY
        titleRow.addArrangedSubview(symbolCircle("bolt.fill", tone: .blue, size: 38))

        let titleText = NSStackView()
        titleText.orientation = .vertical
        titleText.spacing = 1
        titleText.alignment = .leading
        titleText.addArrangedSubview(label("Vibe Coding Guard".localized, size: 20, weight: .bold))
        titleText.addArrangedSubview(label(String(format: "Version %@".localized, aboutVersionLine()), size: 12, color: .secondaryLabelColor))
        titleRow.addArrangedSubview(titleText)
        content.addArrangedSubview(titleRow)

        let tagline = label("Keeps your Mac awake while Codex or Claude Code is open, so long runs finish while you're away.".localized, size: 13, color: .secondaryLabelColor)
        tagline.maximumNumberOfLines = 3
        tagline.widthAnchor.constraint(equalToConstant: 388).isActive = true
        content.addArrangedSubview(tagline)

        content.addArrangedSubview(separator())
        content.addArrangedSubview(label("How it works".localized, size: 11, weight: .semibold, color: .secondaryLabelColor))

        content.addArrangedSubview(manualEntry(
            symbol: "sparkles",
            title: "It's automatic".localized,
            body: "While Codex or Claude Code is open, your Mac stays awake — and sleeps again once you quit them. It watches whether they're running, not whether they're actively working.".localized
        ))
        content.addArrangedSubview(manualEntry(
            symbol: "bolt.fill",
            title: "Always keep awake".localized,
            body: "Turn this on to keep your Mac awake no matter what, until you turn it off.".localized
        ))
        content.addArrangedSubview(manualEntry(
            symbol: "keyboard",
            title: "Keyboard Lock".localized,
            body: "Blocks the keyboard during a run so a pet or child can't interrupt it. Press ⌘⌥⌃L to unlock.".localized
        ))
        content.addArrangedSubview(manualEntry(
            symbol: "laptopcomputer",
            title: "Keep running with lid closed".localized,
            body: "Keep working with the lid shut. Use it on a desk only — it pauses if your Mac gets too hot.".localized
        ))

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = productBackgroundColor().cgColor
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func manualEntry(symbol: String, title: String, body: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .top
        row.widthAnchor.constraint(equalToConstant: 388).isActive = true
        row.addArrangedSubview(symbolCircle(symbol, tone: .neutral, size: 26))

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 2
        text.alignment = .leading
        text.addArrangedSubview(label(title, size: 13, weight: .semibold))
        let bodyLabel = label(body, size: 12, color: .secondaryLabelColor)
        bodyLabel.maximumNumberOfLines = 4
        bodyLabel.widthAnchor.constraint(equalToConstant: 350).isActive = true
        text.addArrangedSubview(bodyLabel)
        row.addArrangedSubview(text)
        return row
    }
}

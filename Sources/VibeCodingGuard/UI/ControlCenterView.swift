import AppKit

extension AppDelegate {
    func showControlCenter() {
        if let existing = controlWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        statusLabels.removeAll()
        actionButtons.removeAll()
        statusViews.removeAll()
        imageViews.removeAll()
        radioButtons.removeAll()
        popups.removeAll()
        segments.removeAll()
        switches.removeAll()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings".localized
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        window.contentView = settingsRootView()
        controlWindow = window
        refreshWindow()
        fitWindowToContent()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func fitWindowToContent() {
        guard let window = controlWindow, let content = window.contentView else {
            return
        }
        content.layoutSubtreeIfNeeded()
        let target = content.fittingSize
        guard target.height > 0 else {
            return
        }
        var frame = window.frame
        let delta = target.height - frame.size.height
        frame.origin.y -= delta
        frame.size.height = target.height
        frame.size.width = max(target.width, 460)
        window.setFrame(frame, display: true, animate: false)
    }

    func settingsRootView() -> NSView {
        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 12
        content.alignment = .leading
        content.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 20, right: 24)
        content.translatesAutoresizingMaskIntoConstraints = false

        let title = label("Settings".localized, size: 18, weight: .bold)
        content.addArrangedSubview(title)
        content.setCustomSpacing(18, after: title)

        // Battery
        content.addArrangedSubview(sectionHeader("Battery".localized))
        content.addArrangedSubview(compactSwitchRow(
            title: "Low battery warnings".localized,
            detail: "Warns you out loud when battery gets low.".localized,
            switchKey: "batteryAlerts",
            action: #selector(switchBatteryAlerts)
        ))
        content.addArrangedSubview(compactPopupRow(title: "Warn me at".localized, popupKey: "warning", titles: ["15%", "20%", "25%", "30%"], action: #selector(changeWarningLevel)))
        let notificationRow = compactButtonRow(
            title: "Notification banners".localized,
            detail: "Optional. Sound alerts still work without banners.".localized,
            buttonKey: "productNotification",
            action: #selector(notificationPermissionAction)
        )
        statusViews["notificationRow"] = notificationRow
        content.addArrangedSubview(notificationRow)
        content.addArrangedSubview(compactButtonRow(title: "Test alert sound".localized, buttonTitle: "Test".localized, buttonKey: "testAlert", action: #selector(testBatteryAlert)))

        content.addArrangedSubview(separator())

        // Display
        content.addArrangedSubview(sectionHeader("Display".localized))
        content.addArrangedSubview(compactSwitchRow(
            title: "Turn off screen when idle".localized,
            detail: "Screen turns off after idle time, but your work keeps running.".localized,
            switchKey: "displayIdleSleep",
            action: #selector(switchDisplayIdleSleep)
        ))
        content.addArrangedSubview(compactPopupRow(title: "Screen off after".localized, popupKey: "idle", titles: ["3 minutes".localized, "5 minutes".localized, "10 minutes".localized, "15 minutes".localized], action: #selector(changeIdleDelay)))

        content.addArrangedSubview(separator())

        // Lid-closed
        content.addArrangedSubview(sectionHeader("Lid closed".localized))
        content.addArrangedSubview(cautionRow("Only use on a desk. Closing the lid in a bag can overheat your Mac — it isn't thermal-safe. It pauses on its own if it gets too hot.".localized))
        let powerPermissionRow = compactButtonRow(
            title: "Disable lid-closed and remove its admin permission.".localized,
            buttonTitle: "Remove".localized,
            buttonKey: "powerPermission",
            action: #selector(removePowerPermissionAction)
        )
        powerPermissionRow.isHidden = !powerPermissionInstalled
        statusViews["powerPermissionRow"] = powerPermissionRow
        content.addArrangedSubview(powerPermissionRow)

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = productBackgroundColor().cgColor
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])
        return container
    }

    func sectionHeader(_ text: String) -> NSView {
        label(text, size: 11, weight: .semibold, color: .secondaryLabelColor)
    }

    func cautionRow(_ text: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .top
        row.widthAnchor.constraint(equalToConstant: 412).isActive = true

        let icon = symbolCircle("exclamationmark.triangle.fill", tone: .warning, size: 22)
        row.addArrangedSubview(icon)

        let text = label(text, size: 12, color: .labelColor)
        text.maximumNumberOfLines = 4
        text.widthAnchor.constraint(equalToConstant: 382).isActive = true
        row.addArrangedSubview(text)
        return row
    }

    // MARK: - Compact row helpers

    func compactPopupRow(title: String, popupKey: String, titles: [String], action: Selector) -> NSView {
        let row = compactRow(title: title)
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: titles)
        popup.target = self
        popup.action = action
        popup.controlSize = .regular
        popups[popupKey] = popup
        row.addArrangedSubview(popup)
        return row
    }

    func compactSwitchRow(title: String, detail: String? = nil, switchKey: String, action: Selector) -> NSView {
        let row = compactRow(title: title, detail: detail)
        let switchControl = NSSwitch()
        switchControl.target = self
        switchControl.action = action
        switches[switchKey] = switchControl
        row.addArrangedSubview(switchControl)
        return row
    }

    func compactButtonRow(title: String, detail: String? = nil, buttonTitle: String = "Allow", buttonKey: String, action: Selector) -> NSView {
        let row = compactRow(title: title, detail: detail)
        let button = NSButton(title: buttonTitle, target: self, action: action)
        button.bezelStyle = .rounded
        actionButtons[buttonKey] = button
        row.addArrangedSubview(button)
        return row
    }

    func compactInfoRow(_ text: String) -> NSView {
        let field = label(text, size: 12, color: .secondaryLabelColor)
        field.maximumNumberOfLines = 2
        field.widthAnchor.constraint(equalToConstant: 412).isActive = true
        return field
    }

    func compactRow(title: String, detail: String? = nil) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 412).isActive = true

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.addArrangedSubview(label(title, size: 13, weight: .medium))
        if let detail {
            let detailLabel = label(detail, size: 12, color: .secondaryLabelColor)
            detailLabel.maximumNumberOfLines = 2
            textStack.addArrangedSubview(detailLabel)
        }

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(spacer())
        return row
    }
}

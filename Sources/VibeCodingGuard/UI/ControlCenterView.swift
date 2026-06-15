import AppKit

extension AppDelegate {
    func showControlCenter(onboarding: Bool, previousFrame: NSRect? = nil) {
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
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = onboarding ? "Set Up Vibe Coding Guard".localized : "Vibe Coding Guard".localized
        window.minSize = NSSize(width: 520, height: 360)
        position(window, previousFrame: previousFrame)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        window.contentView = productRootView()
        controlWindow = window
        refreshWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func productRootView() -> NSView {
        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 14
        content.alignment = .centerX
        content.edgeInsets = NSEdgeInsets(top: 24, left: 26, bottom: 18, right: 26)
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addArrangedSubview(simpleHero())
        content.addArrangedSubview(simplePowerHint())
        content.addArrangedSubview(simpleSetupHint())
        content.addArrangedSubview(simpleCustomizePanel())

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

    func simpleHero() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.spacing = 12
        statusRow.alignment = .centerY

        let statusBadge = RoundedView(fill: NSColor.controlAccentColor.withAlphaComponent(0.16), stroke: nil, radius: 17)
        statusBadge.widthAnchor.constraint(equalToConstant: 34).isActive = true
        statusBadge.heightAnchor.constraint(equalToConstant: 34).isActive = true
        statusViews["productStatusBadge"] = statusBadge

        let statusIcon = NSImageView()
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.imageScaling = .scaleProportionallyDown
        imageViews["productStatusIcon"] = statusIcon
        statusBadge.addSubview(statusIcon)
        NSLayoutConstraint.activate([
            statusIcon.centerXAnchor.constraint(equalTo: statusBadge.centerXAnchor),
            statusIcon.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 18),
            statusIcon.heightAnchor.constraint(equalToConstant: 18)
        ])
        statusRow.addArrangedSubview(statusBadge)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading

        let title = label("Vibe Coding Guard".localized, size: 23, weight: .bold)
        title.maximumNumberOfLines = 2
        statusLabels["productHeroTitle"] = title
        textStack.addArrangedSubview(title)

        let message = label("Choose when your Mac should keep working.".localized, size: 13, color: .secondaryLabelColor)
        message.maximumNumberOfLines = 2
        statusLabels["productHeroMessage"] = message
        textStack.addArrangedSubview(message)

        statusRow.addArrangedSubview(textStack)
        statusRow.addArrangedSubview(spacer())
        stack.addArrangedSubview(statusRow)

        stack.addArrangedSubview(keepAwakeModeRadioGroup())
        return stack
    }

    func simplePowerHint() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 500).isActive = true
        row.addArrangedSubview(symbolCircle("exclamationmark.triangle.fill", tone: .warning, size: 24))
        let text = label("Power adapter not connected. Plug in before leaving a long run.".localized, size: 12, color: .secondaryLabelColor)
        text.maximumNumberOfLines = 2
        row.addArrangedSubview(text)
        row.isHidden = !needsPowerAdapterTip
        statusViews["powerHint"] = row
        return row
    }

    func simpleSetupHint() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 500).isActive = true
        row.addArrangedSubview(symbolCircle("lock.open.fill", tone: .warning, size: 24))
        let text = label("macOS will ask for your password once to allow lid-closed mode.".localized, size: 12, color: .secondaryLabelColor)
        text.maximumNumberOfLines = 2
        row.addArrangedSubview(text)
        row.isHidden = !needsSetupHelp
        statusViews["setupHint"] = row
        return row
    }

    func simpleCustomizePanel() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 500).isActive = true

        stack.addArrangedSubview(customizeGroupControl())
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(customizeGroupsContent())
        return stack
    }

    func keepAwakeModeRadioGroup() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 18
        row.alignment = .centerY

        row.addArrangedSubview(modeRadioButton(title: "Off".localized, mode: .off))
        row.addArrangedSubview(modeRadioButton(title: "Auto".localized, mode: .smart))
        row.addArrangedSubview(modeRadioButton(title: "Always".localized, mode: .alwaysOn))
        selectKeepAwakeRadioButtons()
        return row
    }

    func modeRadioButton(title: String, mode: KeepAwakeMode) -> NSButton {
        let button = NSButton(radioButtonWithTitle: title, target: self, action: #selector(changeKeepAwakeRadioMode(_:)))
        let key = "keepAwake.\(mode.rawValue)"
        button.controlSize = .regular
        button.identifier = NSUserInterfaceItemIdentifier(key)
        radioButtons[key] = button
        return button
    }

    func customizeGroupControl() -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: [
                CustomizeGroup.keepAwake.title,
                CustomizeGroup.display.title,
                CustomizeGroup.battery.title,
                CustomizeGroup.keyboard.title
            ],
            trackingMode: .selectOne,
            target: self,
            action: #selector(changeCustomizeGroup)
        )
        control.segmentStyle = .automatic
        control.controlSize = .regular
        control.widthAnchor.constraint(equalToConstant: 464).isActive = true
        segments["customizeGroup"] = control
        selectCustomizeSegment(control)
        return control
    }

    func customizeGroupsContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.widthAnchor.constraint(equalToConstant: 464).isActive = true

        for group in CustomizeGroup.allCases {
            let content = customizeGroupContent(for: group)
            content.isHidden = group != activeCustomizeGroup
            statusViews["customize.\(group.rawValue)"] = content
            stack.addArrangedSubview(content)
        }

        return stack
    }

    func customizeGroupContent(for group: CustomizeGroup) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.widthAnchor.constraint(equalToConstant: 464).isActive = true

        switch group {
        case .keepAwake:
            stack.addArrangedSubview(compactTextRow(
                title: "Watches for".localized,
                detail: "Codex and Claude Code".localized
            ))
            stack.addArrangedSubview(compactSwitchRow(
                title: "Keep running with lid closed".localized,
                detail: "Needs your admin password once. Only use on a desk, never in a bag, or your Mac could overheat.".localized,
                switchKey: "lidClosed",
                action: #selector(switchLidClosedMode)
            ))
            let powerPermissionRow = compactButtonRow(
                title: "Lid-closed admin access".localized,
                detail: "Allows the app to change lid settings without asking for your password. Your password is not stored.".localized,
                buttonTitle: "Remove".localized,
                buttonKey: "powerPermission",
                action: #selector(removePowerPermissionAction)
            )
            powerPermissionRow.isHidden = !powerPermissionInstalled
            statusViews["powerPermissionRow"] = powerPermissionRow
            stack.addArrangedSubview(powerPermissionRow)
        case .display:
            stack.addArrangedSubview(compactSwitchRow(
                title: "Turn off screen when idle".localized,
                detail: "Screen turns off after idle time, but your work keeps running.".localized,
                switchKey: "displayIdleSleep",
                action: #selector(switchDisplayIdleSleep)
            ))
            stack.addArrangedSubview(compactPopupRow(title: "Screen off after".localized, popupKey: "idle", titles: ["3 minutes".localized, "5 minutes".localized, "10 minutes".localized, "15 minutes".localized], action: #selector(changeIdleDelay)))
            stack.addArrangedSubview(compactButtonRow(title: "Sleep display now".localized, buttonTitle: "Sleep".localized, buttonKey: "displaySleep", action: #selector(displaySleepNow)))
        case .battery:
            stack.addArrangedSubview(compactSwitchRow(
                title: "Low battery warnings".localized,
                detail: "Warns you out loud when battery gets low.".localized,
                switchKey: "batteryAlerts",
                action: #selector(switchBatteryAlerts)
            ))
            stack.addArrangedSubview(compactPopupRow(title: "Low battery alert".localized, popupKey: "warning", titles: ["15%", "20%", "25%", "30%"], action: #selector(changeWarningLevel)))
            stack.addArrangedSubview(compactPopupRow(title: "Critical battery alert".localized, popupKey: "critical", titles: ["5%", "10%", "15%"], action: #selector(changeCriticalLevel)))
            stack.addArrangedSubview(compactButtonRow(
                title: "Notification banners".localized,
                detail: "Optional. Sound alerts still work without banners.".localized,
                buttonKey: "productNotification",
                action: #selector(notificationPermissionAction)
            ))
            stack.addArrangedSubview(compactButtonRow(title: "Test alert sound".localized, buttonTitle: "Test".localized, buttonKey: "testAlert", action: #selector(testBatteryAlert)))
        case .keyboard:
            stack.addArrangedSubview(compactSwitchRow(
                title: "Lock Keyboard".localized,
                detail: "Stops the keyboard while a job is running. Handy if a cat might walk across it. Press ⌘⌥⌃L to unlock anytime.".localized,
                switchKey: "petLock",
                action: #selector(switchPetLock)
            ))
            let status = config.petLockEnabled
                ? "When you turn Keep Awake off, the keyboard unlocks automatically.".localized
                : "Turn this on if a pet or kid might step on the keyboard while a job runs.".localized
            let info = compactInfoRow(status)
            statusLabels["keyboardLockInfo"] = info as? NSTextField
            stack.addArrangedSubview(info)
            let permissionRow = compactButtonRow(
                title: "Accessibility permission".localized,
                detail: "Required so macOS can intercept keyboard input.".localized,
                buttonKey: "petLockPermission",
                action: #selector(petLockPermissionAction)
            )
            permissionRow.isHidden = !(config.petLockEnabled && !petLockAccessibilityTrusted)
            statusViews["keyboardPermissionRow"] = permissionRow
            stack.addArrangedSubview(permissionRow)
        }

        return stack
    }

    func compactTextRow(title: String, detail: String) -> NSView {
        let row = compactRow(title: title)
        let text = label(detail, size: 12, color: .secondaryLabelColor)
        text.alignment = .right
        row.addArrangedSubview(text)
        return row
    }

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
        field.widthAnchor.constraint(equalToConstant: 420).isActive = true
        return field
    }

    func compactRow(title: String, detail: String? = nil) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

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

    func position(_ window: NSWindow, previousFrame: NSRect?) {
        guard let previousFrame else {
            window.center()
            return
        }

        let size = window.frame.size
        let screenFrame = (NSScreen.screens.first { $0.visibleFrame.intersects(previousFrame) } ?? NSScreen.main)?.visibleFrame
        var origin = NSPoint(x: previousFrame.minX, y: previousFrame.maxY - size.height)
        if let screenFrame {
            origin.x = min(max(origin.x, screenFrame.minX), screenFrame.maxX - size.width)
            origin.y = min(max(origin.y, screenFrame.minY), screenFrame.maxY - size.height)
        }
        window.setFrame(NSRect(origin: origin, size: size), display: false)
    }
}

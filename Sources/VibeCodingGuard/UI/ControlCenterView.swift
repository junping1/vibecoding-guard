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
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = onboarding ? "Set Up Vibe Coding Guard" : "Vibe Coding Guard"
        window.minSize = NSSize(width: 520, height: 320)
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
        content.spacing = 16
        content.alignment = .centerX
        content.edgeInsets = NSEdgeInsets(top: 22, left: 26, bottom: 18, right: 26)
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
        stack.spacing = 14
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.spacing = 12
        statusRow.alignment = .centerY

        let statusIcon = NSImageView()
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.imageScaling = .scaleProportionallyDown
        statusIcon.widthAnchor.constraint(equalToConstant: 34).isActive = true
        statusIcon.heightAnchor.constraint(equalToConstant: 34).isActive = true
        imageViews["productStatusIcon"] = statusIcon
        statusRow.addArrangedSubview(statusIcon)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading

        let title = label("Keep Awake", size: 24, weight: .bold)
        title.maximumNumberOfLines = 2
        statusLabels["productHeroTitle"] = title
        textStack.addArrangedSubview(title)

        let message = label("Choose when your Mac should keep working.", size: 13, color: .secondaryLabelColor)
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
        let text = label("Power adapter not connected. Plug in before leaving a long run.", size: 12, color: .secondaryLabelColor)
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
        let text = label("macOS will ask once so VCG can keep working with the lid closed.", size: 12, color: .secondaryLabelColor)
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
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
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

        row.addArrangedSubview(modeRadioButton(title: "Off", mode: .off))
        row.addArrangedSubview(modeRadioButton(title: "Smart", mode: .smart))
        row.addArrangedSubview(modeRadioButton(title: "Always On", mode: .alwaysOn))
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
                title: "Smart watches",
                detail: "Codex and Claude Code"
            ))
            stack.addArrangedSubview(compactSwitchRow(
                title: "Allow work with lid closed",
                detail: "Keeps long jobs running when the MacBook is closed.",
                switchKey: "lidClosed",
                action: #selector(switchLidClosedMode)
            ))
        case .display:
            stack.addArrangedSubview(compactSwitchRow(
                title: "Let display sleep",
                detail: "Turns the screen off after idle time while work keeps running.",
                switchKey: "displayIdleSleep",
                action: #selector(switchDisplayIdleSleep)
            ))
            stack.addArrangedSubview(compactPopupRow(title: "Display sleeps after", popupKey: "idle", titles: ["3 minutes", "5 minutes", "10 minutes", "15 minutes"], action: #selector(changeIdleDelay)))
            stack.addArrangedSubview(compactButtonRow(title: "Sleep display now", buttonTitle: "Sleep", buttonKey: "displaySleep", action: #selector(displaySleepNow)))
        case .battery:
            stack.addArrangedSubview(compactSwitchRow(
                title: "Battery alerts",
                detail: "Plays a warning before long-running work drains the battery.",
                switchKey: "batteryAlerts",
                action: #selector(switchBatteryAlerts)
            ))
            stack.addArrangedSubview(compactPopupRow(title: "Low battery alert", popupKey: "warning", titles: ["15%", "20%", "25%", "30%"], action: #selector(changeWarningLevel)))
            stack.addArrangedSubview(compactPopupRow(title: "Critical battery alert", popupKey: "critical", titles: ["5%", "10%", "15%"], action: #selector(changeCriticalLevel)))
            stack.addArrangedSubview(compactButtonRow(title: "Notification banners", buttonKey: "productNotification", action: #selector(notificationPermissionAction)))
            stack.addArrangedSubview(compactButtonRow(title: "Test alert sound", buttonTitle: "Test", buttonKey: "testAlert", action: #selector(testBatteryAlert)))
        case .keyboard:
            stack.addArrangedSubview(compactSwitchRow(
                title: "Keyboard Lock",
                detail: "Blocks accidental key presses, brightness, and volume keys while Keep Awake is active.",
                switchKey: "petLock",
                action: #selector(switchPetLock)
            ))
            let status = config.petLockEnabled
                ? "When you turn Keep Awake off, the keyboard unlocks automatically."
                : "Turn this on if something may press the keyboard during an agent run."
            let info = compactInfoRow(status)
            statusLabels["keyboardLockInfo"] = info as? NSTextField
            stack.addArrangedSubview(info)
            let permissionRow = compactButtonRow(title: "Keyboard permission", buttonKey: "petLockPermission", action: #selector(petLockPermissionAction))
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

    func compactButtonRow(title: String, buttonTitle: String = "Allow", buttonKey: String, action: Selector) -> NSView {
        let row = compactRow(title: title)
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

import AppKit

extension AppDelegate {
    func showControlCenter(onboarding: Bool) {
        if let existing = controlWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        statusLabels.removeAll()
        actionButtons.removeAll()
        popups.removeAll()
        segments.removeAll()
        switches.removeAll()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: advancedExpanded ? 720 : 320),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = onboarding ? "Set Up Vibe Coding Guard" : "Vibe Coding Guard"
        window.minSize = NSSize(width: 520, height: 320)
        window.center()
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

    func rebuildControlCenterIfNeeded() {
        guard controlWindow != nil else {
            return
        }
        rebuildControlCenter(onboarding: !config.onboardingCompleted)
    }

    func rebuildControlCenter(onboarding: Bool) {
        let oldWindow = controlWindow
        controlWindow = nil
        oldWindow?.close()
        showControlCenter(onboarding: onboarding)
    }

    func productRootView() -> NSView {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 16
        content.alignment = .centerX
        content.edgeInsets = NSEdgeInsets(top: 22, left: 26, bottom: 18, right: 26)
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addArrangedSubview(simpleHeader())
        content.addArrangedSubview(simpleHero())
        if needsSetupHelp {
            content.addArrangedSubview(simpleSetupHint())
        }
        content.addArrangedSubview(simpleCustomizeRow())
        if advancedExpanded {
            content.addArrangedSubview(simpleCustomizePanel())
        }

        root.addArrangedSubview(content)

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = productBackgroundColor().cgColor
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func simpleHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 500).isActive = true

        row.addArrangedSubview(symbolCircle("shield.fill", tone: masterGuardEnabled ? .good : .neutral, size: 28))
        row.addArrangedSubview(label("Vibe Coding Guard", size: 14, weight: .semibold))
        row.addArrangedSubview(spacer())

        let battery = label("Checking", size: 12, weight: .medium, color: .secondaryLabelColor)
        statusLabels["productBatteryLine"] = battery
        row.addArrangedSubview(battery)
        return row
    }

    func simpleHero() -> NSView {
        let card = RoundedView(fill: productCardColor(), stroke: NSColor.separatorColor.withAlphaComponent(0.26), radius: 8)
        card.widthAnchor.constraint(equalToConstant: 500).isActive = true
        card.heightAnchor.constraint(equalToConstant: 170).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = label("Keep Awake", size: 28, weight: .bold)
        title.alignment = .center
        title.maximumNumberOfLines = 2
        statusLabels["productHeroTitle"] = title
        stack.addArrangedSubview(title)

        let message = label("Choose when your Mac should keep working.", size: 13, color: .secondaryLabelColor)
        message.alignment = .center
        statusLabels["productHeroMessage"] = message
        stack.addArrangedSubview(message)

        let modeControl = keepAwakeModeControl(width: 300, controlSize: .large)
        stack.addArrangedSubview(modeControl)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -26),
            stack.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20)
        ])
        return card
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
        return row
    }

    func simpleCustomizeRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 500).isActive = true
        row.addArrangedSubview(spacer())

        let button = NSButton(title: advancedExpanded ? "Hide Customize" : "Customize", target: self, action: #selector(toggleAdvancedOptions))
        button.bezelStyle = .rounded
        row.addArrangedSubview(button)
        return row
    }

    func simpleCustomizePanel() -> NSView {
        let card = RoundedView(fill: productCardColor(), stroke: NSColor.separatorColor.withAlphaComponent(0.26), radius: 8)
        card.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(sectionTitle("Keep Awake"))
        stack.addArrangedSubview(compactTextRow(title: "Smart watches", detail: "Codex, Claude, SSH, VS Code, Cursor"))
        stack.addArrangedSubview(compactSwitchRow(title: "Allow lid closed", switchKey: "lidClosed", action: #selector(switchLidClosedMode)))
        stack.addArrangedSubview(separator())

        stack.addArrangedSubview(sectionTitle("Display"))
        stack.addArrangedSubview(compactSwitchRow(title: "Let display sleep", switchKey: "displayIdleSleep", action: #selector(switchDisplayIdleSleep)))
        stack.addArrangedSubview(compactPopupRow(title: "Display sleeps after", popupKey: "idle", titles: ["3 minutes", "5 minutes", "10 minutes", "15 minutes"], action: #selector(changeIdleDelay)))
        stack.addArrangedSubview(compactButtonRow(title: "Sleep display now", buttonTitle: "Sleep", buttonKey: "displaySleep", action: #selector(displaySleepNow)))
        stack.addArrangedSubview(separator())

        stack.addArrangedSubview(sectionTitle("Battery"))
        stack.addArrangedSubview(compactSwitchRow(title: "Battery alerts", switchKey: "batteryAlerts", action: #selector(switchBatteryAlerts)))
        stack.addArrangedSubview(compactPopupRow(title: "Low battery alert", popupKey: "warning", titles: ["15%", "20%", "25%", "30%"], action: #selector(changeWarningLevel)))
        stack.addArrangedSubview(compactPopupRow(title: "Critical battery alert", popupKey: "critical", titles: ["5%", "10%", "15%"], action: #selector(changeCriticalLevel)))
        stack.addArrangedSubview(compactButtonRow(title: "Notification banners", buttonKey: "productNotification", action: #selector(notificationPermissionAction)))
        stack.addArrangedSubview(compactButtonRow(title: "Test alert sound", buttonTitle: "Test", buttonKey: "testAlert", action: #selector(testBatteryAlert)))
        stack.addArrangedSubview(separator())

        stack.addArrangedSubview(sectionTitle("Keyboard"))
        stack.addArrangedSubview(compactSwitchRow(title: "Pet keyboard lock", switchKey: "petLock", action: #selector(switchPetLock)))
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            stack.addArrangedSubview(compactButtonRow(title: "Keyboard permission", buttonKey: "petLockPermission", action: #selector(petLockPermissionAction)))
        }

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    func keepAwakeModeControl(width: CGFloat, controlSize: NSControl.ControlSize) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: ["Off", "Smart", "Always On"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(changeKeepAwakeMode)
        )
        control.segmentStyle = .rounded
        control.controlSize = controlSize
        control.widthAnchor.constraint(equalToConstant: width).isActive = true
        segments["keepAwakeMode"] = control
        selectKeepAwakeSegment(control)
        return control
    }

    func sectionTitle(_ title: String) -> NSTextField {
        let field = label(title, size: 12, weight: .semibold, color: .secondaryLabelColor)
        field.stringValue = title.uppercased()
        return field
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

    func compactSwitchRow(title: String, switchKey: String, action: Selector) -> NSView {
        let row = compactRow(title: title)
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

    func compactRow(title: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.addArrangedSubview(label(title, size: 13, weight: .medium))
        row.addArrangedSubview(spacer())
        return row
    }
}

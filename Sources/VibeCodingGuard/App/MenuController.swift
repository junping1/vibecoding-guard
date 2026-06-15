import AppKit

extension AppDelegate {
    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "shield", accessibilityDescription: "Vibe Coding Guard") {
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageLeading
        }
        item.button?.title = "Auto"
        item.button?.toolTip = "Vibe Coding Guard keeps long-running work alive while your display can rest."
        statusItem = item
        rebuildMenu()
    }

    func refreshMenuStatus() {
        if keepAwakeShouldRun && caffeinateProcess?.isRunning != true {
            startKeepAwake()
        }

        statusItem?.button?.title = menuBarTitle()
        statusItem?.button?.toolTip = menuTooltip()

        if let image = NSImage(
            systemSymbolName: menuBarSymbolName(),
            accessibilityDescription: menuHeadline()
        ) {
            image.isTemplate = true
            statusItem?.button?.image = image
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(disabledItem(menuHeadline()))
        menu.addItem(disabledItem(menuActivityLine()))
        if needsPowerAdapterTip {
            menu.addItem(disabledItem("Power adapter not connected"))
        }
        menu.addItem(disabledItem(menuEnvironmentLine()))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(keepAwakeModeMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Show Window", #selector(openControlCenter)))
        menu.addItem(toggleActionItem("Keyboard Lock", state: config.petLockEnabled, action: #selector(togglePetLockFromMenu)))
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            menu.addItem(actionItem(keyboardPermissionMenuTitle(), #selector(petLockPermissionAction)))
        }
        menu.addItem(actionItem("Customize...", #selector(openCustomize)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Sleep Display Now", #selector(displaySleepNow)))
        menu.addItem(actionItem("Test Battery Alert", #selector(testBatteryAlert)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Quit Vibe Coding Guard", #selector(quit), key: "q"))
        statusItem?.menu = menu
    }

    func menuBarTitle() -> String {
        menuBarStateText()
    }

    func menuBarStateText() -> String {
        return config.keepAwakeMode.menuTitle
    }

    func keyboardPermissionMenuTitle() -> String {
        petLockPermissionPrompted ? "Open Accessibility Settings..." : "Allow Keyboard Permission..."
    }

    func menuBarSymbolName() -> String {
        if needsAttentionIndicator {
            return "exclamationmark.triangle"
        }
        if config.keepAwakeMode == .off {
            return "shield.slash"
        }
        if config.keepAwakeMode == .smart && !keepAwakeShouldRun {
            return "sparkles"
        }
        if config.keepAwakeMode == .alwaysOn {
            return "bolt.fill"
        }
        return "shield.fill"
    }

    func menuHeadline() -> String {
        switch config.keepAwakeMode {
        case .off:
            return "Off"
        case .smart:
            return "Auto"
        case .alwaysOn:
            return "Always"
        }
    }

    func menuTooltip() -> String {
        let powerLine = needsPowerAdapterTip ? "\nPower adapter not connected" : ""
        return "\(menuHeadline())\n\(menuActivityLine())\(powerLine)\n\(menuEnvironmentLine())"
    }

    func menuActivityLine() -> String {
        let activityText: String
        if config.keepAwakeMode == .smart, let activity = lastAgentActivity {
            activityText = "\(activity.displayName) detected"
        } else if config.keepAwakeMode == .smart {
            activityText = "Ready for Codex or Claude Code"
        } else if config.keepAwakeMode == .alwaysOn {
            activityText = "Keeping Mac awake"
        } else {
            activityText = "Not keeping Mac awake"
        }

        return activityText
    }

    func menuEnvironmentLine() -> String {
        let lidText: String
        if config.lidClosedModeEnabled {
            lidText = lastPowerSettings?.sleepDisabled == true ? "Lid closed allowed" : "Lid setup needed"
        } else {
            lidText = "Lid open only"
        }
        let displayText = config.displayIdleSleepEnabled
            ? "Display sleeps after \(config.idleDisplaySeconds / 60) min"
            : "Display stays on"
        return "\(lidText) - \(displayText)"
    }

    func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func toggleActionItem(_ title: String, state: Bool, action: Selector) -> NSMenuItem {
        let item = actionItem(title, action)
        item.state = state ? .on : .off
        return item
    }

    func keepAwakeModeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Keep Awake", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(modeActionItem("Off", mode: .off, action: #selector(setKeepAwakeOffFromMenu)))
        submenu.addItem(modeActionItem("Auto", mode: .smart, action: #selector(setKeepAwakeSmartFromMenu)))
        submenu.addItem(modeActionItem("Always", mode: .alwaysOn, action: #selector(setKeepAwakeAlwaysOnFromMenu)))
        item.submenu = submenu
        return item
    }

    func modeActionItem(_ title: String, mode: KeepAwakeMode, action: Selector) -> NSMenuItem {
        let item = actionItem(title, action)
        item.state = config.keepAwakeMode == mode ? .on : .off
        return item
    }
}

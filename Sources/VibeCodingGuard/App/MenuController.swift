import AppKit

extension AppDelegate {
    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "shield", accessibilityDescription: "Vibe Coding Guard".localized) {
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
        }
        item.button?.toolTip = "Keeps your Mac awake during long coding sessions.".localized
        statusItem = item
        rebuildMenu()
    }

    func refreshMenuStatus() {
        if keepAwakeShouldRun && caffeinateProcess?.isRunning != true {
            startKeepAwake()
        }

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
        menu.addItem(disabledItem(menuHeadline().localized))
        menu.addItem(disabledItem(menuActivityLine()))
        if needsPowerAdapterTip {
            menu.addItem(disabledItem("Power adapter not connected".localized))
        }
        menu.addItem(disabledItem(menuEnvironmentLine()))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(disabledItem("Keep Awake".localized))
        menu.addItem(modeActionItem("Off".localized, mode: .off, action: #selector(setKeepAwakeOffFromMenu)))
        menu.addItem(modeActionItem("Auto".localized, mode: .smart, action: #selector(setKeepAwakeSmartFromMenu)))
        menu.addItem(modeActionItem("Always".localized, mode: .alwaysOn, action: #selector(setKeepAwakeAlwaysOnFromMenu)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleActionItem("Keyboard Lock".localized, state: config.petLockEnabled, action: #selector(togglePetLockFromMenu)))
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            menu.addItem(actionItem(keyboardPermissionMenuTitle(), #selector(petLockPermissionAction)))
        }
        menu.addItem(actionItem("Sleep Display Now".localized, #selector(displaySleepNow)))
        menu.addItem(actionItem("Test Battery Alert".localized, #selector(testBatteryAlert)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Settings…".localized, #selector(openControlCenter), key: ","))
        menu.addItem(actionItem("About Vibe Coding Guard".localized, #selector(showAbout)))
        menu.addItem(actionItem("Quit Vibe Coding Guard".localized, #selector(quit), key: "q"))
        statusItem?.menu = menu
    }

    func keyboardPermissionMenuTitle() -> String {
        petLockPermissionPrompted ? "Open Accessibility Settings...".localized : "Allow Keyboard Permission...".localized
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
            return "Off".localized
        case .smart:
            return "Auto".localized
        case .alwaysOn:
            return "Always".localized
        }
    }

    func menuTooltip() -> String {
        let powerLine = needsPowerAdapterTip ? "\n" + "Power adapter not connected".localized : ""
        return "\(menuHeadline().localized)\n\(menuActivityLine())\(powerLine)\n\(menuEnvironmentLine())"
    }

    func menuActivityLine() -> String {
        let activityText: String
        if config.keepAwakeMode == .smart, let activity = lastAgentActivity {
            activityText = String(format: "%@ detected".localized, activity.displayName)
        } else if config.keepAwakeMode == .smart {
            activityText = "Ready for Codex or Claude Code".localized
        } else if config.keepAwakeMode == .alwaysOn {
            activityText = "Keeping Mac awake".localized
        } else {
            activityText = "Not keeping Mac awake".localized
        }

        return activityText
    }

    func menuEnvironmentLine() -> String {
        let lidText: String
        if config.lidClosedModeEnabled {
            lidText = lastPowerSettings?.sleepDisabled == true ? "Lid closed allowed".localized : "Lid setup needed".localized
        } else {
            lidText = "Lid open only".localized
        }
        let displayText = config.displayIdleSleepEnabled
            ? String(format: "Display sleeps after %d min".localized, config.idleDisplaySeconds / 60)
            : "Display stays on".localized
        return "\(lidText) • \(displayText)"
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

    func modeActionItem(_ title: String, mode: KeepAwakeMode, action: Selector) -> NSMenuItem {
        let item = actionItem(title, action)
        item.state = config.keepAwakeMode == mode ? .on : .off
        return item
    }
}

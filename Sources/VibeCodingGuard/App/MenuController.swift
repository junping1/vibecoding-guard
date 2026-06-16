import AppKit

extension AppDelegate {
    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "bolt", accessibilityDescription: "Vibe Coding Guard".localized) {
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
        }
        item.button?.toolTip = "Keeps your Mac awake while your coding agents work.".localized
        statusItem = item
        rebuildMenu()
    }

    func refreshMenuStatus() {
        if keepAwakeShouldRun && !thermalThrottled && caffeinateProcess?.isRunning != true {
            startKeepAwake()
        }

        statusItem?.button?.toolTip = menuTooltip()

        if let image = NSImage(
            systemSymbolName: menuBarSymbolName(),
            accessibilityDescription: statusHeadline()
        ) {
            image.isTemplate = true
            statusItem?.button?.image = image
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(disabledItem(statusHeadline()))
        menu.addItem(disabledItem(statusDetail()))
        if needsPowerAdapterTip {
            menu.addItem(disabledItem("On battery — plug in for long runs".localized))
        }
        if needsSetupHelp {
            menu.addItem(disabledItem("Lid-closed needs a one-time approval".localized))
        }
        menu.addItem(disabledItem(menuEnvironmentLine()))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(toggleActionItem("Always keep awake".localized, state: config.alwaysKeepAwake, action: #selector(toggleAlwaysKeepAwake)))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(toggleActionItem("Keyboard Lock".localized, state: config.petLockEnabled, action: #selector(togglePetLockFromMenu)))
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            menu.addItem(actionItem(keyboardPermissionMenuTitle(), #selector(petLockPermissionAction)))
        }
        menu.addItem(toggleActionItem("Keep running with lid closed".localized, state: config.lidClosedModeEnabled, action: #selector(toggleLidClosedFromMenu)))
        menu.addItem(actionItem("Sleep Display Now".localized, #selector(displaySleepNow)))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(actionItem("Advanced…".localized, #selector(showAdvanced)))
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
        return keepAwakeShouldRun ? "bolt" : "bolt.slash"
    }

    func menuTooltip() -> String {
        "\(statusHeadline())\n\(statusDetail())"
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
}

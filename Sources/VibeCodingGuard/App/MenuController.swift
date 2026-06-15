import AppKit

extension AppDelegate {
    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "shield", accessibilityDescription: "Vibe Coding Guard") {
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageLeading
        }
        item.button?.title = "Guard"
        item.button?.toolTip = "Vibe Coding Guard keeps long-running work alive while your display can rest."
        statusItem = item
        rebuildMenu()
    }

    func refreshMenuStatus() {
        if config.keepAwakeEnabled && caffeinateProcess?.isRunning != true {
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
        menu.addItem(disabledItem(menuPowerLine()))
        menu.addItem(disabledItem(menuProtectionLine()))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Show Window", #selector(openControlCenter)))
        menu.addItem(toggleActionItem("Smart Guard", state: config.smartGuardEnabled, action: #selector(toggleSmartGuardFromMenu)))
        menu.addItem(toggleActionItem("Guard", state: masterGuardEnabled, action: #selector(toggleGuardFromMenu)))
        menu.addItem(toggleActionItem("Pet Lock", state: config.petLockEnabled, action: #selector(togglePetLockFromMenu)))
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            menu.addItem(actionItem("Allow Keyboard Permission...", #selector(petLockPermissionAction)))
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
        let state = menuBarStateText()
        if let battery = lastBatteryInfo {
            return "\(state) \(battery.percent)%"
        }
        return state
    }

    func menuBarStateText() -> String {
        if needsSetupHelp {
            return "Setup"
        }
        if !masterGuardEnabled {
            return "Off"
        }
        if smartGuardAutoActive {
            return "Auto"
        }
        if petLockActive {
            return "Pet Lock"
        }
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            return "Pet Setup"
        }
        return "On"
    }

    func menuBarSymbolName() -> String {
        if needsSetupHelp {
            return "shield.lefthalf.filled"
        }
        if !masterGuardEnabled {
            if smartGuardPausedUntilAgentStops {
                return "pause.circle"
            }
            return "shield.slash"
        }
        if petLockActive {
            return "lock.fill"
        }
        return "shield.fill"
    }

    func menuHeadline() -> String {
        if needsSetupHelp {
            return "Setup Needed"
        }
        if !masterGuardEnabled {
            if smartGuardPausedUntilAgentStops {
                return "Guard Paused"
            }
            return "Guard Off"
        }
        if smartGuardAutoActive {
            return "Smart Guard On"
        }
        if petLockActive {
            return "Pet Lock Active"
        }
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            return "Pet Lock Needs Permission"
        }
        return "Guard On"
    }

    func menuTooltip() -> String {
        "\(menuHeadline())\n\(menuPowerLine())\n\(menuProtectionLine())"
    }

    func menuPowerLine() -> String {
        let batteryText: String
        if let battery = lastBatteryInfo {
            batteryText = "Battery: \(battery.percent)% \(friendlyBatteryStatus(battery.status))"
        } else {
            batteryText = "Battery: checking..."
        }

        let displayText = config.displayIdleSleepEnabled
            ? "Display: sleeps after \(config.idleDisplaySeconds / 60) min"
            : "Display: automation off"
        return "\(batteryText) - \(displayText)"
    }

    func menuProtectionLine() -> String {
        let lidText: String
        if config.lidClosedModeEnabled {
            lidText = lastPowerSettings?.sleepDisabled == true ? "Lid: closed allowed" : "Lid: setup needed"
        } else {
            lidText = "Lid: open only"
        }
        return "\(lidText) - \(petLockSummary()) - \(smartGuardSummary())"
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

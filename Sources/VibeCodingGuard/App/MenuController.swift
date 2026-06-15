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

        let menuState = needsSetupHelp ? "Setup" : (masterGuardEnabled ? "On" : "Off")
        if let battery = lastBatteryInfo {
            statusItem?.button?.title = "Guard \(menuState) \(battery.percent)%"
        } else {
            statusItem?.button?.title = "Guard \(menuState)"
        }

        if let image = NSImage(
            systemSymbolName: needsSetupHelp ? "shield.lefthalf.filled" : (masterGuardEnabled ? "shield.fill" : "shield.slash"),
            accessibilityDescription: "Guard is \(menuState)"
        ) {
            image.isTemplate = true
            statusItem?.button?.image = image
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(statusLineItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Open Vibe Coding Guard...", #selector(openControlCenter)))
        menu.addItem(actionItem(masterGuardEnabled ? "Turn Guard Off" : "Turn Guard On", #selector(toggleGuardFromMenu)))
        menu.addItem(actionItem(config.petLockEnabled ? "Turn Pet Lock Off" : "Turn Pet Lock On", #selector(togglePetLockFromMenu)))
        menu.addItem(actionItem("Customize...", #selector(openCustomize)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Sleep Display Now", #selector(displaySleepNow)))
        menu.addItem(actionItem("Test Battery Alert", #selector(testBatteryAlert)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Quit Vibe Coding Guard", #selector(quit), key: "q"))
        statusItem?.menu = menu
    }

    func statusLineItem() -> NSMenuItem {
        let batteryText: String
        if let battery = lastBatteryInfo {
            batteryText = "Battery: \(battery.percent)% \(friendlyBatteryStatus(battery.status))"
        } else {
            batteryText = "Battery: checking..."
        }

        let awakeText = masterGuardEnabled ? "Guard: On" : "Guard: Off"
        let lidText: String
        if config.lidClosedModeEnabled {
            lidText = lastPowerSettings?.sleepDisabled == true ? "Lid closed: allowed" : "Lid closed: setup needed"
        } else {
            lidText = "Lid closed: off"
        }
        let petText = petLockSummary()
        let displayText = config.displayIdleSleepEnabled
            ? "Display sleeps after \(config.idleDisplaySeconds / 60) min"
            : "Display sleep automation off"
        let item = NSMenuItem(
            title: "\(batteryText)\n\(awakeText)\n\(lidText)\n\(petText)\n\(displayText)",
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = false
        return item
    }

    func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }
}

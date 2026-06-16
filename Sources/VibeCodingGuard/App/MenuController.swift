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

        // Status — what's happening right now.
        menu.addItem(disabledItem(statusHeadline()))
        menu.addItem(disabledItem(statusDetail()))
        if needsPowerAdapterTip {
            menu.addItem(warningItem("On battery — plug in for long runs".localized))
        }
        if needsSetupHelp {
            menu.addItem(warningItem("Lid-closed needs a one-time approval".localized))
        }
        menu.addItem(NSMenuItem.separator())

        // Controls — the things you switch on and off.
        menu.addItem(toggleActionItem("Always keep awake".localized, state: config.alwaysKeepAwake, action: #selector(toggleAlwaysKeepAwake), symbol: "bolt.fill"))
        menu.addItem(toggleActionItem("Keyboard Lock".localized, state: config.petLockEnabled, action: #selector(togglePetLockFromMenu), symbol: "keyboard"))
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            menu.addItem(actionItem(keyboardPermissionMenuTitle(), #selector(petLockPermissionAction), symbol: "exclamationmark.triangle.fill"))
        }
        menu.addItem(toggleActionItem("Keep running with lid closed".localized, state: config.lidClosedModeEnabled, action: #selector(toggleLidClosedFromMenu), symbol: "laptopcomputer"))
        menu.addItem(NSMenuItem.separator())

        // App.
        menu.addItem(actionItem("Settings…".localized, #selector(openSettings), symbol: "gearshape"))
        menu.addItem(actionItem("About".localized, #selector(showAbout), symbol: "info.circle"))
        menu.addItem(actionItem("Quit".localized, #selector(quit), key: "q", symbol: "power"))
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

    func menuIcon(_ symbol: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else {
            return nil
        }
        image.isTemplate = true
        return image
    }

    func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func warningItem(_ title: String) -> NSMenuItem {
        let item = disabledItem(title)
        item.image = menuIcon("exclamationmark.triangle.fill")
        return item
    }

    func actionItem(_ title: String, _ action: Selector, key: String = "", symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol {
            item.image = menuIcon(symbol)
        }
        return item
    }

    func toggleActionItem(_ title: String, state: Bool, action: Selector, symbol: String? = nil) -> NSMenuItem {
        let item = actionItem(title, action, symbol: symbol)
        item.state = state ? .on : .off
        return item
    }
}

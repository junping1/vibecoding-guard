import AppKit

extension AppDelegate {
    var needsSetupHelp: Bool {
        keepAwakeShouldRun && (
            lastPowerSettings?.batterySleepMinutes != 0 ||
            (config.lidClosedModeEnabled && lastPowerSettings?.sleepDisabled != true)
        )
    }

    var masterGuardEnabled: Bool {
        keepAwakeShouldRun
    }

    var needsPowerAdapterTip: Bool {
        keepAwakeShouldRun && lastBatteryInfo?.isDischarging == true
    }

    var keepAwakeShouldRun: Bool {
        switch config.keepAwakeMode {
        case .off:
            return false
        case .smart:
            return lastAgentActivity != nil
        case .alwaysOn:
            return true
        }
    }

    func setKeepAwakeMode(_ mode: KeepAwakeMode) {
        config.keepAwakeMode = mode
        smartModeActive = false
        syncKeepAwakeMode()
        syncPetLock()
    }

    func refreshWindow() {
        selectKeepAwakeRadioButtons()
        selectCustomizeSegment(segments["customizeGroup"])
        switches["petLock"]?.state = config.petLockEnabled ? .on : .off
        switches["lidClosed"]?.state = config.lidClosedModeEnabled ? .on : .off
        switches["displayIdleSleep"]?.state = config.displayIdleSleepEnabled ? .on : .off
        switches["batteryAlerts"]?.state = config.batteryAlertsEnabled ? .on : .off

        let product = productHealth()
        statusLabels["productHeroTitle"]?.stringValue = product.title
        statusLabels["productHeroMessage"]?.stringValue = product.message
        updateStatusIcon(tone: product.tone)
        statusViews["powerHint"]?.isHidden = !needsPowerAdapterTip
        statusViews["setupHint"]?.isHidden = !needsSetupHelp
        refreshCustomizeGroupVisibility()
        refreshKeyboardLockInfo()

        refreshNotificationButton()
        refreshPetLockPermissionButton()
        refreshPopups()
    }

    func refreshNotificationButton() {
        guard let button = actionButtons["productNotification"] else {
            return
        }
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            button.title = "Allowed"
            button.isEnabled = false
        case .denied:
            button.title = "Open Settings"
            button.isEnabled = true
        case .notDetermined:
            button.title = "Allow"
            button.isEnabled = true
        @unknown default:
            button.title = "Open Settings"
            button.isEnabled = true
        }
    }

    func selectCustomizeSegment(_ segment: NSSegmentedControl?) {
        guard let segment else {
            return
        }
        segment.selectedSegment = activeCustomizeGroup.rawValue
    }

    func refreshCustomizeGroupVisibility() {
        for group in CustomizeGroup.allCases {
            statusViews["customize.\(group.rawValue)"]?.isHidden = group != activeCustomizeGroup
        }
        statusViews["keyboardPermissionRow"]?.isHidden = !(config.petLockEnabled && !petLockAccessibilityTrusted)
    }

    func refreshKeyboardLockInfo() {
        let text = config.petLockEnabled
            ? "When you turn Keep Awake off, the keyboard unlocks automatically."
            : "Turn this on if something may press the keyboard during an agent run."
        statusLabels["keyboardLockInfo"]?.stringValue = text
    }

    func refreshPetLockPermissionButton() {
        guard let button = actionButtons["petLockPermission"] else {
            return
        }
        button.title = petLockAccessibilityTrusted ? "Allowed" : "Allow"
        button.isEnabled = !petLockAccessibilityTrusted
    }

    func refreshPopups() {
        selectPopup(popups["idle"], value: config.idleDisplaySeconds / 60, values: [3, 5, 10, 15])
        selectPopup(popups["warning"], value: config.warningPercent, values: [15, 20, 25, 30])
        selectPopup(popups["critical"], value: config.criticalPercent, values: [5, 10, 15])
    }

    func selectPopup(_ popup: NSPopUpButton?, value: Int, values: [Int]) {
        guard let popup else {
            return
        }
        let index = values.firstIndex(of: value) ?? 0
        popup.selectItem(at: index)
    }

    func selectKeepAwakeRadioButtons() {
        radioButtons["keepAwake.off"]?.state = config.keepAwakeMode == .off ? .on : .off
        radioButtons["keepAwake.smart"]?.state = config.keepAwakeMode == .smart ? .on : .off
        radioButtons["keepAwake.alwaysOn"]?.state = config.keepAwakeMode == .alwaysOn ? .on : .off
    }

    func productHealth() -> (title: String, message: String, tone: Tone) {
        if keepAwakeShouldRun && caffeinateProcess?.isRunning != true {
            return (
                "Needs Attention",
                "Keep Awake helper is starting.",
                .danger
            )
        }
        if needsSetupHelp {
            return (
                "Permission Needed",
                "Approve closed-lid work once in macOS.",
                .warning
            )
        }
        switch config.keepAwakeMode {
        case .off:
            return (
                "Off",
                "VCG is idle.",
                .neutral
            )
        case .smart:
            if let activity = lastAgentActivity {
                return (
                    "Smart",
                    "\(activity.displayName) detected.",
                    .good
                )
            }
            return (
                "Smart",
                "Watching Codex and Claude Code.",
                .blue
            )
        case .alwaysOn:
            return (
                "Always On",
                guardOnMessage(),
                .good
            )
        }
    }

    func updateStatusIcon(tone: Tone) {
        guard let imageView = imageViews["productStatusIcon"] else {
            return
        }
        imageView.image = NSImage(systemSymbolName: productStatusSymbolName(), accessibilityDescription: nil)
        imageView.contentTintColor = toneColors(tone).foreground
    }

    func productStatusSymbolName() -> String {
        if keepAwakeShouldRun && caffeinateProcess?.isRunning != true {
            return "exclamationmark.triangle.fill"
        }
        if needsSetupHelp {
            return "lock.open.fill"
        }
        switch config.keepAwakeMode {
        case .off:
            return "power.circle"
        case .smart:
            return keepAwakeShouldRun ? "shield.fill" : "sparkles"
        case .alwaysOn:
            return "bolt.fill"
        }
    }

    func guardOnMessage() -> String {
        if smartModeActive, let activity = lastAgentActivity {
            return "\(activity.displayName) detected. Keep Awake is on."
        }
        if config.petLockEnabled && petLockActive {
            return "Keyboard Lock is blocking accidental key presses."
        }
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            return "Keyboard Lock needs Accessibility permission in Customize."
        }
        return config.lidClosedModeEnabled
            ? "You can close the lid. Keep it on a desk, not in a bag."
            : "Keep the lid open. Long jobs keep running while the display can sleep."
    }

    func petLockSummary() -> String {
        if !config.petLockEnabled {
            return "Keyboard Lock: off"
        }
        if petLockActive {
            return "Keyboard Lock: blocking keys"
        }
        if !petLockAccessibilityTrusted {
            return "Keyboard Lock: permission needed"
        }
        return masterGuardEnabled ? "Keyboard Lock: starting" : "Keyboard Lock: waits for Keep Awake"
    }

    func friendlyBatteryStatus(_ status: String) -> String {
        let lower = status.lowercased()
        if lower.contains("charging") {
            return "Charging"
        }
        if lower.contains("discharging") {
            return "On battery"
        }
        if lower.contains("charged") || lower.contains("finishing") {
            return "Charged"
        }
        return status.capitalized
    }
}

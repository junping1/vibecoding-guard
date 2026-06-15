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

        if let battery = lastBatteryInfo {
            statusLabels["productBatteryLine"]?.stringValue = "\(battery.percent)% \(friendlyBatteryStatus(battery.status))"
        } else {
            statusLabels["productBatteryLine"]?.stringValue = "Checking battery"
        }

        let product = productHealth()
        statusLabels["productHeroTitle"]?.stringValue = product.title
        statusLabels["productHeroMessage"]?.stringValue = product.message

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
                "Keep Awake needs attention",
                "The helper is not running yet. VCG will keep trying.",
                .danger
            )
        }
        if needsSetupHelp {
            return (
                "Permission needed",
                "macOS needs one approval before closed-lid work can run.",
                .warning
            )
        }
        switch config.keepAwakeMode {
        case .off:
            return (
                "Keep Awake is Off",
                "VCG is not keeping the Mac awake.",
                .neutral
            )
        case .smart:
            if let activity = lastAgentActivity {
                return (
                    "Smart is On",
                    "\(activity.displayName) detected. Your Mac will keep working.",
                    .good
                )
            }
            return (
                "Smart is Ready",
                "VCG will keep awake when Codex, Claude, SSH, or a watched work app is active.",
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

    func guardOnMessage() -> String {
        if smartModeActive, let activity = lastAgentActivity {
            return "\(activity.displayName) detected. Keep Awake is on."
        }
        if config.petLockEnabled && petLockActive {
            return "Pet Lock is blocking accidental key presses."
        }
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            return "Pet Lock needs Accessibility permission in Customize."
        }
        return config.lidClosedModeEnabled
            ? "You can close the lid. Keep it on a desk, not in a bag."
            : "Keep the lid open. Long jobs keep running while the display can sleep."
    }

    func petLockSummary() -> String {
        if !config.petLockEnabled {
            return "Pet Lock: off"
        }
        if petLockActive {
            return "Pet Lock: blocking keyboard"
        }
        if !petLockAccessibilityTrusted {
            return "Pet Lock: permission needed"
        }
        return masterGuardEnabled ? "Pet Lock: starting" : "Pet Lock: waits for Keep Awake"
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

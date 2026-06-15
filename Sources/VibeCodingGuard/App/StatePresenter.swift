import AppKit

extension AppDelegate {
    var needsSetupHelp: Bool {
        lastPowerSettings?.batterySleepMinutes != 0 ||
            (config.lidClosedModeEnabled && lastPowerSettings?.sleepDisabled != true)
    }

    var masterGuardEnabled: Bool {
        config.keepAwakeEnabled && config.displayIdleSleepEnabled && config.batteryAlertsEnabled
    }

    func setMasterGuard(enabled: Bool, source: GuardChangeSource = .manual) {
        if source == .manual {
            config.smartGuardOwnsGuard = false
            if enabled {
                smartGuardAutoActive = false
                smartGuardPausedUntilAgentStops = false
            } else if lastAgentActivity != nil {
                smartGuardAutoActive = false
                smartGuardPausedUntilAgentStops = true
            }
        }

        if source == .smart {
            config.smartGuardOwnsGuard = enabled
        }

        config.keepAwakeEnabled = enabled
        config.displayIdleSleepEnabled = enabled
        config.batteryAlertsEnabled = enabled
        applyKeepAwakeState()
    }

    func refreshWindow() {
        switches["keepAwake"]?.state = config.keepAwakeEnabled ? .on : .off
        switches["smartGuard"]?.state = config.smartGuardEnabled ? .on : .off
        switches["petLock"]?.state = config.petLockEnabled ? .on : .off
        switches["lidClosed"]?.state = config.lidClosedModeEnabled ? .on : .off
        switches["batteryAlerts"]?.state = config.batteryAlertsEnabled ? .on : .off

        if let battery = lastBatteryInfo {
            statusLabels["productBatteryLine"]?.stringValue = "\(battery.percent)% \(friendlyBatteryStatus(battery.status))"
        } else {
            statusLabels["productBatteryLine"]?.stringValue = "Checking battery"
        }

        let product = productHealth()
        statusLabels["productHeroTitle"]?.stringValue = product.title
        statusLabels["productHeroMessage"]?.stringValue = product.message

        if let primary = actionButtons["simplePrimary"] {
            primary.title = simplePrimaryTitle()
        }

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

    func productHealth() -> (title: String, message: String, tone: Tone) {
        if config.keepAwakeEnabled && caffeinateProcess?.isRunning != true {
            return (
                "Guard needs attention",
                "The keep-awake helper is not running. Guard will keep trying, but long jobs may not be protected yet.",
                .danger
            )
        }
        if needsSetupHelp {
            return (
                "Allow & turn on",
                "macOS will ask once so Guard can keep working with the lid closed.",
                .warning
            )
        }
        if !masterGuardEnabled {
            if smartGuardPausedUntilAgentStops {
                return (
                    "Guard is Paused",
                    "Smart Guard will wait until this agent run ends.",
                    .neutral
                )
            }
            if config.smartGuardEnabled {
                return (
                    "Guard is Ready",
                    "It turns on automatically when Codex or Claude starts working.",
                    .blue
                )
            }
            return (
                "Guard is Off",
                "Turn it on before you step away from long-running work.",
                .neutral
            )
        }
        return (
            "Guard is On",
            guardOnMessage(),
            .good
        )
    }

    func guardOnMessage() -> String {
        if smartGuardAutoActive, let activity = lastAgentActivity {
            return "\(activity.displayName) detected. Guard turned on automatically."
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
        return masterGuardEnabled ? "Pet Lock: starting" : "Pet Lock: waits for Guard"
    }

    func simplePrimaryTitle() -> String {
        if needsSetupHelp {
            return "Allow & Turn On"
        }
        return masterGuardEnabled ? "Turn Off" : "Turn On"
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

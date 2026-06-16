import AppKit

extension AppDelegate {
    // MARK: - Core state

    var agentDetected: Bool {
        lastAgentActivity != nil
    }

    var manualOverrideActive: Bool {
        guard let until = config.manualOverrideUntil else {
            return false
        }
        return until.timeIntervalSinceNow > 0
    }

    var overrideIsIndefinite: Bool {
        guard let until = config.manualOverrideUntil else {
            return false
        }
        // "Until I stop" is stored as a far-future sentinel.
        return until.timeIntervalSinceNow > 60 * 60 * 24 * 365 * 5
    }

    var keepAwakeShouldRun: Bool {
        agentDetected || manualOverrideActive
    }

    var masterGuardEnabled: Bool {
        keepAwakeShouldRun
    }

    var needsSetupHelp: Bool {
        keepAwakeShouldRun &&
            config.lidClosedModeEnabled &&
            lastPowerSettings?.sleepDisabled != true
    }

    var needsPowerAdapterTip: Bool {
        keepAwakeShouldRun && lastBatteryInfo?.isDischarging == true
    }

    var needsKeepAwakeHelperAttention: Bool {
        keepAwakeShouldRun && caffeinateProcess?.isRunning != true && !thermalThrottled
    }

    var needsAttentionIndicator: Bool {
        thermalThrottled || needsKeepAwakeHelperAttention || needsSetupHelp || needsPowerAdapterTip
    }

    // MARK: - Status copy (shared by the menu today, the popover later)

    func statusHeadline() -> String {
        if thermalThrottled {
            return "Cooling down".localized
        }
        if let activity = lastAgentActivity {
            return String(format: "%@ is working".localized, activity.kind.rawValue)
        }
        if manualOverrideActive {
            return "Keeping your Mac awake".localized
        }
        return "Standing by".localized
    }

    func statusDetail() -> String {
        if thermalThrottled {
            return "Paused lid-closed work to cool down.".localized
        }
        if needsKeepAwakeHelperAttention {
            return "Starting…".localized
        }
        if agentDetected {
            return "Your Mac will stay awake.".localized
        }
        if manualOverrideActive {
            return overrideRemainingText()
        }
        return "Ready for Codex or Claude Code.".localized
    }

    func statusTone() -> Tone {
        if needsAttentionIndicator {
            return .warning
        }
        return keepAwakeShouldRun ? .good : .neutral
    }

    func overrideRemainingText() -> String {
        guard manualOverrideActive else {
            return ""
        }
        if overrideIsIndefinite {
            return "On until you turn it off.".localized
        }
        let seconds = max(0, Int(config.manualOverrideUntil?.timeIntervalSinceNow ?? 0))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm left.".localized, hours, minutes)
        }
        return String(format: "%dm left.".localized, max(1, minutes))
    }

    // MARK: - Advanced window refresh (no-op when closed)

    func refreshWindow() {
        guard controlWindow != nil else {
            return
        }
        switches["displayIdleSleep"]?.state = config.displayIdleSleepEnabled ? .on : .off
        switches["batteryAlerts"]?.state = config.batteryAlertsEnabled ? .on : .off
        refreshNotificationButton()
        refreshPowerPermissionButton()
        refreshPopups()
        statusViews["powerPermissionRow"]?.isHidden = !powerPermissionInstalled
        fitWindowToContent()
    }

    func refreshNotificationButton() {
        guard let button = actionButtons["productNotification"] else {
            return
        }
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            statusViews["notificationRow"]?.isHidden = true
        case .denied:
            statusViews["notificationRow"]?.isHidden = false
            button.title = "Open Settings".localized
            button.isEnabled = true
        case .notDetermined:
            statusViews["notificationRow"]?.isHidden = false
            button.title = "Allow".localized
            button.isEnabled = true
        @unknown default:
            statusViews["notificationRow"]?.isHidden = false
            button.title = "Open Settings".localized
            button.isEnabled = true
        }
    }

    func refreshPowerPermissionButton() {
        guard let button = actionButtons["powerPermission"] else {
            return
        }
        button.title = powerPermissionInstalled ? "Remove".localized : "Not Set".localized
        button.isEnabled = powerPermissionInstalled
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
}

import AppKit

extension AppDelegate {
    // MARK: - Core state

    var agentDetected: Bool {
        lastAgentActivity != nil
    }

    var keepAwakeShouldRun: Bool {
        agentDetected || config.alwaysKeepAwake
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
        if config.alwaysKeepAwake {
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
        if config.alwaysKeepAwake {
            return "Always on, until you turn it off.".localized
        }
        return "Sleeps normally. I wake up automatically when an agent runs.".localized
    }

    func statusTone() -> Tone {
        if needsAttentionIndicator {
            return .warning
        }
        return keepAwakeShouldRun ? .good : .neutral
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
    }

    func selectPopup(_ popup: NSPopUpButton?, value: Int, values: [Int]) {
        guard let popup else {
            return
        }
        let index = values.firstIndex(of: value) ?? 0
        popup.selectItem(at: index)
    }
}

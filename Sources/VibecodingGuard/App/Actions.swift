import AppKit
import UserNotifications

extension AppDelegate {
    @objc func openControlCenter() {
        showControlCenter(onboarding: false)
    }

    @objc func openCustomize() {
        advancedExpanded = true
        showControlCenter(onboarding: false)
    }

    @objc func toggleGuardFromMenu() {
        let enabled = !masterGuardEnabled
        setMasterGuard(enabled: enabled)
        setLidClosedMode(enabled: enabled)
        runChecks()
        rebuildControlCenterIfNeeded()
    }

    @objc func displaySleepNow() {
        _ = runCommand("/usr/bin/pmset", ["displaysleepnow"])
    }

    @objc func testBatteryAlert() {
        sendBatteryAlert(
            title: "Vibecoding Guard test",
            message: "Battery warnings are ready.",
            critical: false
        )
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    @objc func simplePrimaryAction() {
        if needsSetupHelp {
            setMasterGuard(enabled: true)
            setLidClosedMode(enabled: true)
            if notificationStatus == .notDetermined {
                requestNotificationPermission()
            }
            config.onboardingCompleted = true
            runChecks()
            rebuildControlCenterIfNeeded()
            return
        }

        let enabled = !masterGuardEnabled
        setMasterGuard(enabled: enabled)
        setLidClosedMode(enabled: enabled)
        if enabled && notificationStatus == .notDetermined {
            requestNotificationPermission()
        }
        config.onboardingCompleted = true
        runChecks()
        rebuildControlCenterIfNeeded()
    }

    @objc func switchKeepAwake() {
        config.keepAwakeEnabled = switches["keepAwake"]?.state == .on
        applyKeepAwakeState()
        runChecks()
    }

    @objc func switchLidClosedMode() {
        let enabled = switches["lidClosed"]?.state == .on
        setLidClosedMode(enabled: enabled)
        runChecks()
        rebuildControlCenterIfNeeded()
    }

    @objc func switchBatteryAlerts() {
        config.batteryAlertsEnabled = switches["batteryAlerts"]?.state == .on
        runChecks()
    }

    @objc func toggleAdvancedOptions() {
        advancedExpanded.toggle()
        rebuildControlCenter(onboarding: !config.onboardingCompleted)
    }

    @objc func notificationPermissionAction() {
        switch notificationStatus {
        case .denied:
            openNotificationSettings()
        case .authorized, .provisional, .ephemeral:
            testBatteryAlert()
        case .notDetermined:
            requestNotificationPermission()
        @unknown default:
            openNotificationSettings()
        }
    }

    @objc func changeIdleDelay() {
        let values = [3, 5, 10, 15]
        let index = popups["idle"]?.indexOfSelectedItem ?? 1
        config.idleDisplaySeconds = values[min(max(index, 0), values.count - 1)] * 60
        runChecks()
    }

    @objc func changeWarningLevel() {
        let values = [15, 20, 25, 30]
        let index = popups["warning"]?.indexOfSelectedItem ?? 1
        config.warningPercent = values[min(max(index, 0), values.count - 1)]
        if config.criticalPercent >= config.warningPercent {
            config.criticalPercent = max(5, config.warningPercent - 10)
        }
        runChecks()
    }

    @objc func changeCriticalLevel() {
        let values = [5, 10, 15]
        let index = popups["critical"]?.indexOfSelectedItem ?? 1
        config.criticalPercent = values[min(max(index, 0), values.count - 1)]
        if config.criticalPercent >= config.warningPercent {
            config.warningPercent = min(30, config.criticalPercent + 10)
        }
        runChecks()
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshNotificationStatus()
                self?.refreshWindow()
            }
        }
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLidClosedMode(enabled: Bool) {
        config.lidClosedModeEnabled = enabled
        if enabled {
            guard lastPowerSettings?.sleepDisabled != true else {
                return
            }
        } else {
            guard lastPowerSettings?.sleepDisabled == true else {
                return
            }
        }

        let value = enabled ? "1" : "0"
        let command = enabled
            ? "/usr/bin/pmset -a sleep 0; /usr/bin/pmset -a disablesleep \(value)"
            : "/usr/bin/pmset -a disablesleep \(value)"
        let prompt = enabled
            ? "Allow Vibecoding Guard to keep working while the lid is closed. Keep the Mac on a desk, not in a bag."
            : "Allow Vibecoding Guard to turn off closed-lid work mode."
        let script = """
        do shell script "\(command)" with administrator privileges with prompt "\(appleScriptQuoted(prompt))"
        """
        _ = runCommand("/usr/bin/osascript", ["-e", script])
        lastPowerSettings = readPowerSettings()
    }

    func enableBatterySleepSetting() {
        let script = """
        do shell script "/usr/bin/pmset -b sleep 0" with administrator privileges with prompt "Allow Vibecoding Guard to keep long-running work alive on battery."
        """
        _ = runCommand("/usr/bin/osascript", ["-e", script])
        lastPowerSettings = readPowerSettings()
        refreshWindow()
    }
}

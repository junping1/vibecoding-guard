import AppKit
import UserNotifications

extension AppDelegate {
    @objc func openControlCenter() {
        showControlCenter(onboarding: false)
    }

    @objc func openCustomize() {
        showControlCenter(onboarding: false)
    }

    @objc func setKeepAwakeOffFromMenu() {
        setKeepAwakeMode(.off)
        runChecks()
    }

    @objc func setKeepAwakeSmartFromMenu() {
        setKeepAwakeMode(.smart)
        runChecks()
    }

    @objc func setKeepAwakeAlwaysOnFromMenu() {
        setKeepAwakeMode(.alwaysOn)
        runChecks()
    }

    @objc func togglePetLockFromMenu() {
        setPetLock(enabled: !config.petLockEnabled, promptIfNeeded: true)
        runChecks()
    }

    @objc func displaySleepNow() {
        _ = runCommand("/usr/bin/pmset", ["displaysleepnow"])
    }

    @objc func testBatteryAlert() {
        sendBatteryAlert(
            title: "Vibe Coding Guard test",
            message: "Battery warnings are ready.",
            critical: false
        )
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    @objc func changeKeepAwakeRadioMode(_ sender: NSButton) {
        let rawMode = sender.identifier?.rawValue.replacingOccurrences(of: "keepAwake.", with: "") ?? KeepAwakeMode.smart.rawValue
        setKeepAwakeMode(KeepAwakeMode(rawValue: rawMode) ?? .smart)
        runChecks()
    }

    @objc func changeCustomizeGroup() {
        let selected = segments["customizeGroup"]?.selectedSegment ?? 0
        activeCustomizeGroup = CustomizeGroup(rawValue: selected) ?? .keepAwake
        refreshWindow()
    }

    @objc func switchDisplayIdleSleep() {
        config.displayIdleSleepEnabled = switches["displayIdleSleep"]?.state == .on
        runChecks()
    }

    @objc func switchPetLock() {
        let enabled = switches["petLock"]?.state == .on
        setPetLock(enabled: enabled, promptIfNeeded: true)
        runChecks()
    }

    @objc func switchLidClosedMode() {
        let enabled = switches["lidClosed"]?.state == .on
        setLidClosedMode(enabled: enabled)
        runChecks()
    }

    @objc func switchBatteryAlerts() {
        config.batteryAlertsEnabled = switches["batteryAlerts"]?.state == .on
        syncPetLock()
        runChecks()
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

    @objc func petLockPermissionAction() {
        requestPetLockPermission()
        syncPetLock()
        runChecks()
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
            ? "Allow Vibe Coding Guard to keep working while the lid is closed. Keep the Mac on a desk, not in a bag."
            : "Allow Vibe Coding Guard to turn off closed-lid work mode."
        let script = """
        do shell script "\(command)" with administrator privileges with prompt "\(appleScriptQuoted(prompt))"
        """
        withKeyboardInputTemporarilyAllowed {
            _ = runCommand("/usr/bin/osascript", ["-e", script])
        }
        lastPowerSettings = readPowerSettings()
    }

    func enableBatterySleepSetting() {
        let script = """
        do shell script "/usr/bin/pmset -b sleep 0" with administrator privileges with prompt "Allow Vibe Coding Guard to keep long-running work alive on battery."
        """
        withKeyboardInputTemporarilyAllowed {
            _ = runCommand("/usr/bin/osascript", ["-e", script])
        }
        lastPowerSettings = readPowerSettings()
        refreshWindow()
    }
}

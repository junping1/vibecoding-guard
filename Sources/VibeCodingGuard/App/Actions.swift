import AppKit
import UserNotifications

extension AppDelegate {
    @objc func openControlCenter() {
        showControlCenter(onboarding: false)
    }

    @objc func dismissOnboardingIntro() {
        config.onboardingCompleted = true
        showingOnboarding = false
        refreshWindow()
    }

    @objc func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let versionLine = build.isEmpty ? version : "\(version) (\(build))"

        let alert = NSAlert()
        alert.messageText = "Vibe Coding Guard".localized
        alert.informativeText = String(
            format: "Version %@\n\nKeeps your Mac awake while Codex or Claude Code is working.\n\nLid-closed mode adds one narrow sudoers rule for the exact pmset commands it needs. Remove it anytime from the Agents tab.".localized,
            versionLine
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK".localized)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
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
            title: "Vibe Coding Guard test".localized,
            message: "Battery warnings are ready.".localized,
            critical: false,
            isTest: true
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
        refreshPetLockPermissionStatus()
        if petLockAccessibilityTrusted {
            syncPetLock()
            refreshWindow()
            return
        }

        if petLockPermissionPrompted {
            openAccessibilitySettings()
        } else {
            requestPetLockPermission()
        }
        runChecks()
    }

    @objc func removePowerPermissionAction() {
        _ = removeOneTimePmsetPermission()
        refreshPowerPermissionStatus()
        refreshWindow()
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
        lidClosedApprovalFailed = false
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

        let commands = lidClosedPmsetCommands(enabled: enabled)
        if runSavedPmsetCommands(commands) {
            lastPowerSettings = readPowerSettings()
            syncLidClosedConfigFromSystem()
            return
        }

        guard installOneTimePmsetPermission() else {
            lastPowerSettings = readPowerSettings()
            syncLidClosedConfigFromSystem()
            lidClosedApprovalFailed = enabled && !config.lidClosedModeEnabled
            refreshWindow()
            return
        }

        _ = runSavedPmsetCommands(commands)
        lastPowerSettings = readPowerSettings()
        syncLidClosedConfigFromSystem()
        lidClosedApprovalFailed = enabled && !config.lidClosedModeEnabled
    }

    func syncLidClosedConfigFromSystem() {
        config.lidClosedModeEnabled = lastPowerSettings?.sleepDisabled == true
    }

    var powerPermissionFilePath: String {
        "/private/etc/sudoers.d/vibecodingguard"
    }

    func refreshPowerPermissionStatus() {
        powerPermissionInstalled = FileManager.default.fileExists(atPath: powerPermissionFilePath)
    }

    func lidClosedPmsetCommands(enabled: Bool) -> [[String]] {
        enabled
            ? [["-a", "sleep", "0"], ["-a", "disablesleep", "1"]]
            : [["-a", "disablesleep", "0"]]
    }

    func runSavedPmsetCommands(_ commands: [[String]]) -> Bool {
        for arguments in commands {
            guard runCommandStatus("/usr/bin/sudo", ["-n", "/usr/bin/pmset"] + arguments) == 0 else {
                return false
            }
        }
        return true
    }

    func installOneTimePmsetPermission() -> Bool {
        let userName = NSUserName()
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard userName.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return false
        }

        let sudoersContent = """
        # Vibe Coding Guard one-time power permission.
        # Allows only the exact pmset commands needed for closed-lid work.
        Cmnd_Alias VCG_PMSET = /usr/bin/pmset -a sleep 0, /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -b sleep 0
        \(userName) ALL=(root) NOPASSWD: VCG_PMSET
        """
        let installScript = """
        set -e
        file=\(shellQuoted(powerPermissionFilePath))
        tmp=$(/usr/bin/mktemp /tmp/vibecodingguard.sudoers.XXXXXX)
        /bin/cat > "$tmp" <<'VCG_SUDOERS'
        \(sudoersContent)
        VCG_SUDOERS
        /usr/sbin/visudo -cf "$tmp"
        /usr/sbin/chown root:wheel "$tmp"
        /bin/chmod 0440 "$tmp"
        /bin/mv "$tmp" "$file"
        if ! /usr/sbin/visudo -cf /private/etc/sudoers; then
          /bin/rm -f "$file"
          exit 1
        fi
        """
        let command = "/bin/sh -c \(shellQuoted(installScript))"
        let script = """
        do shell script "\(appleScriptQuoted(command))" with administrator privileges with prompt "\("Allow Vibe Coding Guard to change lid-closed settings without asking for your password again.".localized)"
        """
        let installed = withKeyboardInputTemporarilyAllowed {
            runCommandStatus("/usr/bin/osascript", ["-e", script]) == 0
        }
        refreshPowerPermissionStatus()
        return installed
    }

    func removeOneTimePmsetPermission() -> Bool {
        let removeScript = """
        set -e
        file=\(shellQuoted(powerPermissionFilePath))
        if [ -e "$file" ]; then
          /bin/rm -f "$file"
        fi
        /usr/sbin/visudo -cf /private/etc/sudoers
        """
        let command = "/bin/sh -c \(shellQuoted(removeScript))"
        let script = """
        do shell script "\(appleScriptQuoted(command))" with administrator privileges with prompt "\("Remove the admin permission for lid-closed settings.".localized)"
        """
        let removed = withKeyboardInputTemporarilyAllowed {
            runCommandStatus("/usr/bin/osascript", ["-e", script]) == 0
        }
        refreshPowerPermissionStatus()
        return removed
    }

    func enableBatterySleepSetting() {
        let commands = [["-b", "sleep", "0"]]
        if !runSavedPmsetCommands(commands) {
            guard installOneTimePmsetPermission() else {
                lastPowerSettings = readPowerSettings()
                refreshWindow()
                return
            }
            _ = runSavedPmsetCommands(commands)
        }
        lastPowerSettings = readPowerSettings()
        refreshWindow()
    }
}

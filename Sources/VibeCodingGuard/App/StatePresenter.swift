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

    var needsKeepAwakeHelperAttention: Bool {
        keepAwakeShouldRun && caffeinateProcess?.isRunning != true
    }

    var needsAttentionIndicator: Bool {
        needsKeepAwakeHelperAttention || needsSetupHelp || needsPowerAdapterTip
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
        statusLabels["productHeroTitle"]?.stringValue = "Vibe Coding Guard"
        statusLabels["productHeroMessage"]?.stringValue = product.message
        updateStatusIcon(tone: product.tone)
        statusViews["powerHint"]?.isHidden = !needsPowerAdapterTip
        statusViews["setupHint"]?.isHidden = !needsSetupHelp
        refreshCustomizeGroupVisibility()
        refreshKeyboardLockInfo()

        refreshNotificationButton()
        refreshPetLockPermissionButton()
        refreshPowerPermissionButton()
        refreshPopups()
    }

    func refreshNotificationButton() {
        guard let button = actionButtons["productNotification"] else {
            return
        }
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            button.title = "Allowed".localized
            button.isEnabled = false
        case .denied:
            button.title = "Open Settings".localized
            button.isEnabled = true
        case .notDetermined:
            button.title = "Allow".localized
            button.isEnabled = true
        @unknown default:
            button.title = "Open Settings".localized
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
        statusViews["powerPermissionRow"]?.isHidden = !powerPermissionInstalled
    }

    func refreshKeyboardLockInfo() {
        let text: String
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            text = petLockPermissionPrompted
                ? "Turn on Vibe Coding Guard in System Settings ▸ Accessibility, then come back.".localized
                : "macOS will ask for permission once so the keyboard can be locked.".localized
        } else if config.petLockEnabled {
            text = "When you turn Keep Awake off, the keyboard unlocks automatically.".localized
        } else {
            text = "Turn this on if a pet or kid might step on the keyboard while a job runs.".localized
        }
        statusLabels["keyboardLockInfo"]?.stringValue = text
    }

    func refreshPetLockPermissionButton() {
        guard let button = actionButtons["petLockPermission"] else {
            return
        }
        if petLockAccessibilityTrusted {
            button.title = "Allowed".localized
        } else if petLockPermissionPrompted {
            button.title = "Open Settings".localized
        } else {
            button.title = "Allow".localized
        }
        button.isEnabled = !petLockAccessibilityTrusted
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

    func selectKeepAwakeRadioButtons() {
        radioButtons["keepAwake.off"]?.state = config.keepAwakeMode == .off ? .on : .off
        radioButtons["keepAwake.smart"]?.state = config.keepAwakeMode == .smart ? .on : .off
        radioButtons["keepAwake.alwaysOn"]?.state = config.keepAwakeMode == .alwaysOn ? .on : .off
    }

    func productHealth() -> (title: String, message: String, tone: Tone) {
        let title = config.keepAwakeMode.title

        if needsKeepAwakeHelperAttention {
            return (
                title,
                "Starting up…".localized,
                .warning
            )
        }
        if needsSetupHelp {
            return (
                title,
                "macOS needs a one-time approval for lid-closed mode.".localized,
                .warning
            )
        }
        if needsPowerAdapterTip {
            return (
                title,
                productModeMessage(),
                .warning
            )
        }

        return (
            title,
            productModeMessage(),
            productModeTone()
        )
    }

    func productModeMessage() -> String {
        switch config.keepAwakeMode {
        case .off:
            return "Standing by.".localized
        case .smart:
            if let activity = lastAgentActivity {
                return String(format: "%@ detected.".localized, activity.displayName)
            }
            return "Ready for Codex or Claude Code.".localized
        case .alwaysOn:
            return guardOnMessage()
        }
    }

    func productModeTone() -> Tone {
        switch config.keepAwakeMode {
        case .off:
            return .neutral
        case .smart:
            return keepAwakeShouldRun ? .good : .blue
        case .alwaysOn:
            return .good
        }
    }

    func updateStatusIcon(tone: Tone) {
        guard let imageView = imageViews["productStatusIcon"] else {
            return
        }
        let colors = toneColors(tone)
        imageView.image = NSImage(systemSymbolName: productStatusSymbolName(), accessibilityDescription: nil)
        imageView.contentTintColor = colors.foreground
        (statusViews["productStatusBadge"] as? RoundedView)?.update(fill: colors.background)
    }

    func productStatusSymbolName() -> String {
        if needsAttentionIndicator {
            return "exclamationmark.triangle.fill"
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
            return String(format: "%@ detected. Keep Awake is on.".localized, activity.displayName)
        }
        if config.petLockEnabled && petLockActive {
            return "Keyboard is locked.".localized
        }
        if config.petLockEnabled && !petLockAccessibilityTrusted {
            return "Keyboard Lock needs permission. Open the Keyboard tab.".localized
        }
        return config.lidClosedModeEnabled
            ? "You can close the lid. Keep it on a desk, not in a bag.".localized
            : "Keep the lid open. Your work keeps going even when the screen turns off.".localized
    }

    func petLockSummary() -> String {
        if !config.petLockEnabled {
            return "Keyboard Lock: off".localized
        }
        if petLockActive {
            return "Keyboard Lock: blocking keys".localized
        }
        if !petLockAccessibilityTrusted {
            return "Keyboard Lock: permission needed".localized
        }
        return masterGuardEnabled ? "Keyboard Lock: starting".localized : "Keyboard Lock: waits for Keep Awake".localized
    }

    func friendlyBatteryStatus(_ status: String) -> String {
        let lower = status.lowercased()
        if lower.contains("charging") {
            return "Charging".localized
        }
        if lower.contains("discharging") {
            return "On battery".localized
        }
        if lower.contains("charged") || lower.contains("finishing") {
            return "Charged".localized
        }
        return status.capitalized
    }
}

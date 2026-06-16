import AppKit
import Foundation

extension AppDelegate {
    func registerThermalObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        evaluateThermalState()
    }

    @objc func thermalStateChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.evaluateThermalState()
        }
    }

    // Sense the danger instead of warning about it: when lid-closed work gets hot,
    // back off so the Mac can cool, then resume automatically.
    func evaluateThermalState() {
        guard config.lidClosedModeEnabled else {
            if thermalThrottled {
                releaseThermalBackoff()
            }
            return
        }

        let state = ProcessInfo.processInfo.thermalState
        let isHot = state == .serious || state == .critical

        if isHot && keepAwakeShouldRun && !thermalThrottled {
            engageThermalBackoff()
        } else if !isHot && thermalThrottled {
            releaseThermalBackoff()
        }
    }

    private func engageThermalBackoff() {
        thermalThrottled = true
        // Stop preventing sleep so a lidded Mac can cool down.
        _ = runSavedPmsetCommands([["-a", "disablesleep", "0"]])
        lastPowerSettings = readPowerSettings()
        stopKeepAwake()
        sendUserNotification(
            title: "Cooling down".localized,
            message: "Your Mac is getting warm, so I paused lid-closed work to protect it. It resumes automatically once it cools.".localized
        )
        refreshMenuStatus()
        refreshWindow()
    }

    private func releaseThermalBackoff() {
        thermalThrottled = false
        if keepAwakeShouldRun && config.lidClosedModeEnabled {
            _ = runSavedPmsetCommands([["-a", "sleep", "0"], ["-a", "disablesleep", "1"]])
            lastPowerSettings = readPowerSettings()
        }
        if keepAwakeShouldRun {
            startKeepAwake()
        }
        refreshMenuStatus()
        refreshWindow()
    }
}

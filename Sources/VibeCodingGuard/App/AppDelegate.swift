import AppKit
import Foundation
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    enum Tone {
        case good
        case warning
        case danger
        case neutral
        case blue
    }

    let config = GuardConfig()
    var statusItem: NSStatusItem?
    var caffeinateProcess: Process?
    var batteryTimer: Timer?
    var displayTimer: Timer?
    var menuTimer: Timer?
    var lastAgentActivity: AgentActivity?
    var smartGuardAutoActive = false
    var smartGuardPausedUntilAgentStops = false
    var lastBatteryInfo: BatteryInfo?
    var lastPowerSettings: PowerSettings?
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    var lastWarningAlert: Date?
    var lastCriticalAlert: Date?
    var lastDisplaySleep = Date.distantPast
    var petLockEventTap: CFMachPort?
    var petLockRunLoopSource: CFRunLoopSource?
    var petLockAccessibilityTrusted = false
    var petLockActive = false
    var controlWindow: NSWindow?
    var statusLabels: [String: NSTextField] = [:]
    var actionButtons: [String: NSButton] = [:]
    var popups: [String: NSPopUpButton] = [:]
    var switches: [String: NSSwitch] = [:]
    var advancedExpanded = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        refreshNotificationStatus()
        applyKeepAwakeState()
        syncPetLock()
        startTimers()
        runChecks()

        if !config.onboardingCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showControlCenter(onboarding: true)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlCenter(onboarding: !config.onboardingCompleted)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopKeepAwake()
        stopPetLock()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === controlWindow else {
            return
        }

        controlWindow = nil
        statusLabels.removeAll()
        actionButtons.removeAll()
        popups.removeAll()
        switches.removeAll()
    }

    func startTimers() {
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        displayTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkDisplayIdle()
        }
        menuTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.runChecks()
        }
    }

    func runChecks() {
        syncSmartGuard()
        lastPowerSettings = readPowerSettings()
        syncPetLock()
        refreshNotificationStatus()
        checkBattery()
        checkDisplayIdle()
        refreshMenuStatus()
        refreshWindow()
    }
}

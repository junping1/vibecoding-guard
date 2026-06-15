import AppKit
import Foundation
import UserNotifications

enum CustomizeGroup: Int, CaseIterable {
    case keepAwake
    case display
    case battery
    case keyboard

    var title: String {
        switch self {
        case .keepAwake:
            return "Keep Awake"
        case .display:
            return "Display"
        case .battery:
            return "Battery"
        case .keyboard:
            return "Keyboard"
        }
    }
}

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
    var smartModeActive = false
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
    var statusViews: [String: NSView] = [:]
    var imageViews: [String: NSImageView] = [:]
    var statusLabels: [String: NSTextField] = [:]
    var actionButtons: [String: NSButton] = [:]
    var radioButtons: [String: NSButton] = [:]
    var popups: [String: NSPopUpButton] = [:]
    var segments: [String: NSSegmentedControl] = [:]
    var switches: [String: NSSwitch] = [:]
    var activeCustomizeGroup: CustomizeGroup = .keepAwake

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        refreshNotificationStatus()
        syncKeepAwakeMode()
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
        statusViews.removeAll()
        imageViews.removeAll()
        statusLabels.removeAll()
        actionButtons.removeAll()
        radioButtons.removeAll()
        popups.removeAll()
        segments.removeAll()
        switches.removeAll()
    }

    func startTimers() {
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.runLiveChecks()
        }
        displayTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkDisplayIdle()
        }
        menuTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.runChecks()
        }
    }

    func runChecks() {
        lastPowerSettings = readPowerSettings()
        refreshNotificationStatus()
        runLiveChecks()
        checkDisplayIdle()
    }

    func runLiveChecks() {
        syncKeepAwakeMode()
        syncPetLock()
        checkBattery()
        refreshMenuStatus()
        refreshWindow()
    }
}

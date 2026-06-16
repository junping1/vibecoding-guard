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
            return "Agents".localized
        case .display:
            return "Display".localized
        case .battery:
            return "Battery".localized
        case .keyboard:
            return "Keyboard".localized
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
    var petLockPermissionPrompted = false
    var accessibilityPermissionTimer: Timer?
    var accessibilityPermissionPollCount = 0
    var petLockActive = false
    var powerPermissionInstalled = false
    var showingOnboarding = false
    var lidClosedApprovalFailed = false
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
        accessibilityPermissionTimer?.invalidate()
        stopKeepAwake()
        stopPetLock()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === controlWindow else {
            return
        }

        if !config.onboardingCompleted {
            config.onboardingCompleted = true
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
        refreshPowerPermissionStatus()
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

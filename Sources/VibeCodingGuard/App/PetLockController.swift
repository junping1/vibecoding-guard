import ApplicationServices
import AppKit

private let petLockSystemDefinedEventType = CGEventType(rawValue: 14)!

private let petLockEventCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    return delegate.handlePetLockEvent(proxy: proxy, type: type, event: event)
}

extension AppDelegate {
    var petLockShouldBeActive: Bool {
        config.petLockEnabled && masterGuardEnabled
    }

    func setPetLock(enabled: Bool, promptIfNeeded: Bool) {
        config.petLockEnabled = enabled
        if enabled, promptIfNeeded, !petLockAccessibilityTrusted {
            requestPetLockPermission()
        }
        syncPetLock()
    }

    func syncPetLock() {
        refreshPetLockPermissionStatus()
        if petLockShouldBeActive && petLockAccessibilityTrusted {
            startPetLock()
        } else {
            stopPetLock()
        }
    }

    func refreshPetLockPermissionStatus() {
        petLockAccessibilityTrusted = AXIsProcessTrusted()
    }

    func requestPetLockPermission() {
        refreshPetLockPermissionStatus()
        guard !petLockAccessibilityTrusted else {
            syncPetLock()
            refreshWindow()
            return
        }

        petLockPermissionPrompted = true
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        petLockAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        startAccessibilityPermissionPolling()
        refreshWindow()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startAccessibilityPermissionPolling()
    }

    func startAccessibilityPermissionPolling() {
        accessibilityPermissionTimer?.invalidate()
        accessibilityPermissionPollCount = 0
        accessibilityPermissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            accessibilityPermissionPollCount += 1
            refreshPetLockPermissionStatus()
            if petLockAccessibilityTrusted {
                timer.invalidate()
                accessibilityPermissionTimer = nil
                syncPetLock()
                refreshMenuStatus()
                refreshWindow()
                return
            }

            refreshWindow()
            if accessibilityPermissionPollCount >= 60 {
                timer.invalidate()
                accessibilityPermissionTimer = nil
            }
        }
    }

    func startPetLock() {
        guard petLockEventTap == nil else {
            petLockActive = true
            return
        }

        let eventMask =
            CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.keyUp.rawValue) |
            CGEventMask(1 << CGEventType.flagsChanged.rawValue) |
            CGEventMask(1 << petLockSystemDefinedEventType.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: petLockEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            petLockActive = false
            refreshPetLockPermissionStatus()
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        petLockEventTap = eventTap
        petLockRunLoopSource = runLoopSource
        petLockActive = true

        sendUserNotification(
            title: "Keyboard locked".localized,
            message: "Vibe Coding Guard is blocking the keyboard. Press ⌘⌥⌃L to unlock.".localized
        )
    }

    func stopPetLock() {
        if let runLoopSource = petLockRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap = petLockEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        petLockRunLoopSource = nil
        petLockEventTap = nil
        petLockActive = false
    }

    func withKeyboardInputTemporarilyAllowed<Result>(_ work: () -> Result) -> Result {
        let shouldRestore = petLockActive
        if shouldRestore {
            stopPetLock()
        }
        let result = work()
        if shouldRestore {
            syncPetLock()
        }
        return result
    }

    func handlePetLockEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = petLockEventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard petLockShouldBeActive else {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown, isPetLockUnlockShortcut(event) {
            DispatchQueue.main.async { [weak self] in
                self?.setPetLock(enabled: false, promptIfNeeded: false)
                self?.runChecks()
            }
        }

        return nil
    }

    private func isPetLockUnlockShortcut(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        return keyCode == 37 &&
            flags.contains(.maskCommand) &&
            flags.contains(.maskAlternate) &&
            flags.contains(.maskControl)
    }
}

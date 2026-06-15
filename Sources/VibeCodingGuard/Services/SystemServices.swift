import AppKit
import Foundation
import UserNotifications

extension AppDelegate {
    func checkBattery() {
        guard let battery = readBatteryInfo() else {
            return
        }
        lastBatteryInfo = battery

        guard config.keepAwakeMode != .off, config.batteryAlertsEnabled, battery.isDischarging else {
            lastWarningAlert = nil
            lastCriticalAlert = nil
            return
        }

        if battery.percent <= config.criticalPercent {
            maybeSendBatteryAlert(
                level: "critical",
                repeatAfter: 300,
                title: "Battery critical",
                message: "Battery is at \(battery.percent) percent. Plug in power now.",
                critical: true
            )
        } else if battery.percent <= config.warningPercent {
            maybeSendBatteryAlert(
                level: "warning",
                repeatAfter: 900,
                title: "Battery low",
                message: "Battery is at \(battery.percent) percent. Please plug in power.",
                critical: false
            )
        }
    }

    func maybeSendBatteryAlert(
        level: String,
        repeatAfter: TimeInterval,
        title: String,
        message: String,
        critical: Bool
    ) {
        let now = Date()
        let lastAlert = level == "critical" ? lastCriticalAlert : lastWarningAlert
        if let lastAlert, now.timeIntervalSince(lastAlert) < repeatAfter {
            return
        }

        if level == "critical" {
            lastCriticalAlert = now
        } else {
            lastWarningAlert = now
        }
        sendBatteryAlert(title: title, message: message, critical: critical)
    }

    func sendBatteryAlert(title: String, message: String, critical: Bool) {
        sendUserNotification(title: title, message: message)

        if let sound = NSSound(named: critical ? "Sosumi" : "Glass") {
            sound.play()
        }
        speak(critical ? "Battery critical. Plug in power now." : "Battery low. Please plug in power.")
    }

    func sendUserNotification(title: String, message: String) {
        if notificationStatus == .denied || notificationStatus == .notDetermined {
            displayNotificationFallback(title: title, message: message)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "vibecoding-guard-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if error != nil {
                self?.displayNotificationFallback(title: title, message: message)
            }
        }
    }

    func displayNotificationFallback(title: String, message: String) {
        let safeTitle = appleScriptQuoted(title)
        let safeMessage = appleScriptQuoted(message)
        let script = "display notification \"\(safeMessage)\" with title \"\(safeTitle)\""
        _ = runCommand("/usr/bin/osascript", ["-e", script])
    }

    func speak(_ text: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = [text]
        try? process.run()
    }

    func appleScriptQuoted(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    func checkDisplayIdle() {
        guard config.keepAwakeMode != .off, config.displayIdleSleepEnabled else {
            return
        }
        guard let idleSeconds = readIdleSeconds() else {
            return
        }
        guard idleSeconds >= config.idleDisplaySeconds else {
            return
        }
        guard Date().timeIntervalSince(lastDisplaySleep) >= 60 else {
            return
        }

        lastDisplaySleep = Date()
        _ = runCommand("/usr/bin/pmset", ["displaysleepnow"])
    }

    func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationStatus = settings.authorizationStatus
                self?.refreshWindow()
            }
        }
    }

    func readBatteryInfo() -> BatteryInfo? {
        let output = runCommand("/usr/bin/pmset", ["-g", "batt"])
        guard let line = output.split(separator: "\n").first(where: { $0.contains("InternalBattery") }) else {
            return nil
        }

        let percentRegex = try? NSRegularExpression(pattern: #"(\d+)%"#)
        let lineString = String(line)
        let range = NSRange(lineString.startIndex..<lineString.endIndex, in: lineString)
        guard
            let match = percentRegex?.firstMatch(in: lineString, range: range),
            let percentRange = Range(match.range(at: 1), in: lineString),
            let percent = Int(lineString[percentRange])
        else {
            return nil
        }

        let parts = lineString.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        let status = parts.count > 1 ? parts[1] : "unknown"
        return BatteryInfo(percent: percent, status: status)
    }

    func readPowerSettings() -> PowerSettings? {
        let output = runCommand("/usr/bin/pmset", ["-g", "custom"])
        let liveOutput = runCommand("/usr/bin/pmset", ["-g"])
        var currentSection: String?
        var batterySleep: Int?
        var acSleep: Int?
        var sleepDisabled: Bool?

        for line in output.split(separator: "\n").map(String.init) {
            if line.hasPrefix("Battery Power:") {
                currentSection = "battery"
                continue
            }
            if line.hasPrefix("AC Power:") {
                currentSection = "ac"
                continue
            }
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count >= 2, parts[0] == "sleep", let value = Int(parts[1]) else {
                continue
            }
            if currentSection == "battery" {
                batterySleep = value
            } else if currentSection == "ac" {
                acSleep = value
            }
        }

        for line in liveOutput.split(separator: "\n").map(String.init) {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count >= 2, parts[0] == "SleepDisabled", let value = Int(parts[1]) else {
                continue
            }
            sleepDisabled = value == 1
        }

        return PowerSettings(
            batterySleepMinutes: batterySleep,
            acSleepMinutes: acSleep,
            sleepDisabled: sleepDisabled
        )
    }

    func readIdleSeconds() -> Int? {
        let output = runCommand("/usr/sbin/ioreg", ["-c", "IOHIDSystem", "-r", "-d", "1"])
        let regex = try? NSRegularExpression(pattern: #"\"HIDIdleTime\"\s*=\s*(\d+)"#)
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard
            let match = regex?.firstMatch(in: output, range: range),
            let valueRange = Range(match.range(at: 1), in: output),
            let nanoseconds = UInt64(output[valueRange])
        else {
            return nil
        }
        return Int(nanoseconds / 1_000_000_000)
    }

    @discardableResult
    func runCommand(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            NSLog("Vibe Coding Guard: command failed \(path): \(error)")
            return ""
        }
    }
}

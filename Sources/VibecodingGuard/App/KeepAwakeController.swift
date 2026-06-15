import Foundation

extension AppDelegate {
    func applyKeepAwakeState() {
        if config.keepAwakeEnabled {
            startKeepAwake()
        } else {
            stopKeepAwake()
        }
    }

    func startKeepAwake() {
        if caffeinateProcess?.isRunning == true {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-im"]
        do {
            try process.run()
            caffeinateProcess = process
        } catch {
            NSLog("Vibecoding Guard: failed to start caffeinate: \(error)")
        }
    }

    func stopKeepAwake() {
        if caffeinateProcess?.isRunning == true {
            caffeinateProcess?.terminate()
        }
        caffeinateProcess = nil
    }
}

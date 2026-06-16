import Foundation

final class GuardConfig {
    private let defaults = UserDefaults.standard

    private func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    private func integer(forKey key: String, default defaultValue: Int) -> Int {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        let value = defaults.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }

    // Manual override: keep awake even when no agent is running.
    // nil = no override; .distantFuture = "until I stop".
    var manualOverrideUntil: Date? {
        get {
            let timestamp = defaults.double(forKey: "manualOverrideUntil")
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: "manualOverrideUntil")
            } else {
                defaults.removeObject(forKey: "manualOverrideUntil")
            }
        }
    }

    var displayIdleSleepEnabled: Bool {
        get { bool(forKey: "displayIdleSleepEnabled", default: true) }
        set { defaults.set(newValue, forKey: "displayIdleSleepEnabled") }
    }

    var batteryAlertsEnabled: Bool {
        get { bool(forKey: "batteryAlertsEnabled", default: true) }
        set { defaults.set(newValue, forKey: "batteryAlertsEnabled") }
    }

    var lidClosedModeEnabled: Bool {
        get { bool(forKey: "lidClosedModeEnabled", default: false) }
        set { defaults.set(newValue, forKey: "lidClosedModeEnabled") }
    }

    var petLockEnabled: Bool {
        get { bool(forKey: "petLockEnabled", default: false) }
        set { defaults.set(newValue, forKey: "petLockEnabled") }
    }

    var onboardingCompleted: Bool {
        get { bool(forKey: "onboardingCompleted", default: false) }
        set { defaults.set(newValue, forKey: "onboardingCompleted") }
    }

    var idleDisplaySeconds: Int {
        get { integer(forKey: "idleDisplaySeconds", default: 600) }
        set { defaults.set(max(60, newValue), forKey: "idleDisplaySeconds") }
    }

    var warningPercent: Int {
        get { integer(forKey: "warningPercent", default: 20) }
        set { defaults.set(min(80, max(5, newValue)), forKey: "warningPercent") }
    }

    var criticalPercent: Int {
        get { integer(forKey: "criticalPercent", default: 10) }
        set { defaults.set(min(40, max(1, newValue)), forKey: "criticalPercent") }
    }
}

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

    var keepAwakeEnabled: Bool {
        get { bool(forKey: "keepAwakeEnabled", default: true) }
        set { defaults.set(newValue, forKey: "keepAwakeEnabled") }
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
        get { bool(forKey: "lidClosedModeEnabled", default: true) }
        set { defaults.set(newValue, forKey: "lidClosedModeEnabled") }
    }

    var petLockEnabled: Bool {
        get { bool(forKey: "petLockEnabled", default: false) }
        set { defaults.set(newValue, forKey: "petLockEnabled") }
    }

    var smartGuardEnabled: Bool {
        get { bool(forKey: "smartGuardEnabled", default: true) }
        set { defaults.set(newValue, forKey: "smartGuardEnabled") }
    }

    var smartGuardOwnsGuard: Bool {
        get { bool(forKey: "smartGuardOwnsGuard", default: false) }
        set { defaults.set(newValue, forKey: "smartGuardOwnsGuard") }
    }

    var onboardingCompleted: Bool {
        get { bool(forKey: "onboardingCompleted", default: false) }
        set { defaults.set(newValue, forKey: "onboardingCompleted") }
    }

    var idleDisplaySeconds: Int {
        get { integer(forKey: "idleDisplaySeconds", default: 300) }
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

import Foundation

struct BatteryInfo {
    let percent: Int
    let status: String

    var isDischarging: Bool {
        status.lowercased().contains("discharging")
    }
}

struct PowerSettings {
    let batterySleepMinutes: Int?
    let acSleepMinutes: Int?
    let sleepDisabled: Bool?
}

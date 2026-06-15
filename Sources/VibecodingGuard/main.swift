import AppKit
import Foundation
import UserNotifications

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

final class RoundedView: NSView {
    private var fillColor: NSColor
    private var strokeColor: NSColor?
    private let radius: CGFloat

    init(fill: NSColor, stroke: NSColor? = nil, radius: CGFloat = 8) {
        self.fillColor = fill
        self.strokeColor = stroke
        self.radius = radius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        applyLayer()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayer()
    }

    func update(fill: NSColor, stroke: NSColor? = nil) {
        fillColor = fill
        strokeColor = stroke
        applyLayer()
    }

    private func applyLayer() {
        layer?.cornerRadius = radius
        layer?.masksToBounds = true
        layer?.backgroundColor = layerColor(fillColor)
        if let strokeColor {
            layer?.borderWidth = 1
            layer?.borderColor = layerColor(strokeColor)
        } else {
            layer?.borderWidth = 0
            layer?.borderColor = nil
        }
    }

    private func layerColor(_ color: NSColor) -> CGColor {
        color.usingColorSpace(.deviceRGB)?.cgColor ?? color.cgColor
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private enum Tone {
        case good
        case warning
        case danger
        case neutral
        case blue
    }

    private let config = GuardConfig()
    private var statusItem: NSStatusItem?
    private var caffeinateProcess: Process?
    private var batteryTimer: Timer?
    private var displayTimer: Timer?
    private var menuTimer: Timer?
    private var lastBatteryInfo: BatteryInfo?
    private var lastPowerSettings: PowerSettings?
    private var notificationStatus: UNAuthorizationStatus = .notDetermined
    private var lastWarningAlert: Date?
    private var lastCriticalAlert: Date?
    private var lastDisplaySleep = Date.distantPast
    private var controlWindow: NSWindow?
    private var statusLabels: [String: NSTextField] = [:]
    private var controls: [String: NSButton] = [:]
    private var actionButtons: [String: NSButton] = [:]
    private var popups: [String: NSPopUpButton] = [:]
    private var pillViews: [String: RoundedView] = [:]
    private var switches: [String: NSSwitch] = [:]
    private var advancedExpanded = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        refreshNotificationStatus()
        applyKeepAwakeState()
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
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === controlWindow {
            controlWindow = nil
            statusLabels.removeAll()
            controls.removeAll()
            actionButtons.removeAll()
            popups.removeAll()
            pillViews.removeAll()
            switches.removeAll()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "shield", accessibilityDescription: "Vibecoding Guard") {
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageLeading
        }
        item.button?.title = "Guard"
        item.button?.toolTip = "Vibecoding Guard keeps long-running work alive while your display can rest."
        statusItem = item
        rebuildMenu()
    }

    private func startTimers() {
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

    private func runChecks() {
        lastPowerSettings = readPowerSettings()
        refreshNotificationStatus()
        checkBattery()
        checkDisplayIdle()
        refreshMenuStatus()
        refreshWindow()
    }

    private func refreshMenuStatus() {
        if config.keepAwakeEnabled && caffeinateProcess?.isRunning != true {
            startKeepAwake()
        }

        let menuState = needsSetupHelp ? "Setup" : (masterGuardEnabled ? "On" : "Off")
        if let battery = lastBatteryInfo {
            statusItem?.button?.title = "Guard \(menuState) \(battery.percent)%"
        } else {
            statusItem?.button?.title = "Guard \(menuState)"
        }

        if let image = NSImage(
            systemSymbolName: needsSetupHelp ? "shield.lefthalf.filled" : (masterGuardEnabled ? "shield.fill" : "shield.slash"),
            accessibilityDescription: "Guard is \(menuState)"
        ) {
            image.isTemplate = true
            statusItem?.button?.image = image
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(statusLineItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Open Vibecoding Guard...", #selector(openControlCenter)))
        menu.addItem(actionItem(masterGuardEnabled ? "Turn Guard Off" : "Turn Guard On", #selector(toggleGuardFromMenu)))
        menu.addItem(actionItem("Customize...", #selector(openCustomize)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Sleep Display Now", #selector(displaySleepNow)))
        menu.addItem(actionItem("Test Battery Alert", #selector(testBatteryAlert)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Quit Vibecoding Guard", #selector(quit), key: "q"))
        statusItem?.menu = menu
    }

    private func statusLineItem() -> NSMenuItem {
        let batteryText: String
        if let battery = lastBatteryInfo {
            batteryText = "Battery: \(battery.percent)% \(friendlyBatteryStatus(battery.status))"
        } else {
            batteryText = "Battery: checking..."
        }

        let awakeText = masterGuardEnabled ? "Guard: On" : "Guard: Off"
        let lidText: String
        if config.lidClosedModeEnabled {
            lidText = lastPowerSettings?.sleepDisabled == true ? "Lid closed: allowed" : "Lid closed: setup needed"
        } else {
            lidText = "Lid closed: off"
        }
        let displayText = config.displayIdleSleepEnabled
            ? "Display sleeps after \(config.idleDisplaySeconds / 60) min"
            : "Display sleep automation off"
        let item = NSMenuItem(
            title: "\(batteryText)\n\(awakeText)\n\(lidText)\n\(displayText)",
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func toggleItem(title: String, state: Bool, action: Selector) -> NSMenuItem {
        let item = actionItem(title, action)
        item.state = state ? .on : .off
        return item
    }

    @objc private func openControlCenter() {
        showControlCenter(onboarding: false)
    }

    @objc private func openOnboarding() {
        showControlCenter(onboarding: true)
    }

    @objc private func openCustomize() {
        advancedExpanded = true
        showControlCenter(onboarding: false)
    }

    @objc private func toggleGuardFromMenu() {
        let enabled = !masterGuardEnabled
        setMasterGuard(enabled: enabled)
        setLidClosedMode(enabled: enabled)
        runChecks()
    }

    @objc private func toggleKeepAwake() {
        config.keepAwakeEnabled.toggle()
        applyKeepAwakeState()
        runChecks()
    }

    @objc private func toggleDisplayIdleSleep() {
        config.displayIdleSleepEnabled.toggle()
        runChecks()
    }

    @objc private func toggleBatteryAlerts() {
        config.batteryAlertsEnabled.toggle()
        runChecks()
    }

    @objc private func displaySleepNow() {
        _ = runCommand("/usr/bin/pmset", ["displaysleepnow"])
    }

    @objc private func testBatteryAlert() {
        sendBatteryAlert(
            title: "Vibecoding Guard test",
            message: "Battery warnings are ready.",
            critical: false
        )
    }

    @objc private func openPowerSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func applyKeepAwakeState() {
        if config.keepAwakeEnabled {
            startKeepAwake()
        } else {
            stopKeepAwake()
        }
    }

    private func startKeepAwake() {
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

    private func stopKeepAwake() {
        if caffeinateProcess?.isRunning == true {
            caffeinateProcess?.terminate()
        }
        caffeinateProcess = nil
    }

    private func showControlCenter(onboarding: Bool) {
        if let existing = controlWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        statusLabels.removeAll()
        controls.removeAll()
        actionButtons.removeAll()
        popups.removeAll()
        pillViews.removeAll()
        switches.removeAll()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: advancedExpanded ? 560 : 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = onboarding ? "Set Up Vibecoding Guard" : "Vibecoding Guard"
        window.minSize = NSSize(width: 520, height: 340)
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        window.contentView = productRootView(onboarding: onboarding)
        controlWindow = window
        refreshWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func productRootView(onboarding: Bool) -> NSView {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 16
        content.alignment = .centerX
        content.edgeInsets = NSEdgeInsets(top: 22, left: 26, bottom: 18, right: 26)
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addArrangedSubview(simpleHeader())
        content.addArrangedSubview(simpleHero())
        if needsSetupHelp {
            content.addArrangedSubview(simpleSetupHint())
        }
        content.addArrangedSubview(simpleCustomizeRow())
        if advancedExpanded {
            content.addArrangedSubview(simpleCustomizePanel())
        }

        root.addArrangedSubview(content)

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = productBackgroundColor().cgColor
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private var needsSetupHelp: Bool {
        lastPowerSettings?.batterySleepMinutes != 0 ||
            (config.lidClosedModeEnabled && lastPowerSettings?.sleepDisabled != true)
    }

    private func simpleHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 500).isActive = true

        row.addArrangedSubview(symbolCircle("shield.fill", tone: masterGuardEnabled ? .good : .neutral, size: 28))
        let title = label("Vibecoding Guard", size: 14, weight: .semibold)
        row.addArrangedSubview(title)
        row.addArrangedSubview(spacer())

        let battery = label("Checking", size: 12, weight: .medium, color: .secondaryLabelColor)
        statusLabels["productBatteryLine"] = battery
        row.addArrangedSubview(battery)
        return row
    }

    private func simpleHero() -> NSView {
        let card = RoundedView(fill: productCardColor(), stroke: NSColor.separatorColor.withAlphaComponent(0.26), radius: 8)
        card.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 26, left: 26, bottom: 26, right: 26)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = label("Guard is On", size: 28, weight: .bold)
        title.alignment = .center
        title.maximumNumberOfLines = 2
        statusLabels["productHeroTitle"] = title
        stack.addArrangedSubview(title)

        let message = label("You can close the lid. Keep it on a desk, not in a bag.", size: 13, color: .secondaryLabelColor)
        message.alignment = .center
        message.maximumNumberOfLines = 2
        message.widthAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true
        statusLabels["productHeroMessage"] = message
        stack.addArrangedSubview(message)

        let primary = NSButton(title: "Turn Off", target: self, action: #selector(simplePrimaryAction))
        primary.bezelStyle = .rounded
        primary.controlSize = .large
        primary.keyEquivalent = "\r"
        actionButtons["simplePrimary"] = primary
        stack.addArrangedSubview(primary)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func simpleSetupHint() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 500).isActive = true
        row.addArrangedSubview(symbolCircle("lock.open.fill", tone: .warning, size: 24))
        let text = label("macOS will ask once so Guard can run with the lid closed.", size: 12, color: .secondaryLabelColor)
        text.maximumNumberOfLines = 2
        row.addArrangedSubview(text)
        return row
    }

    private func simpleCustomizeRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 500).isActive = true
        row.addArrangedSubview(spacer())

        let button = NSButton(title: advancedExpanded ? "Hide Customize" : "Customize", target: self, action: #selector(toggleAdvancedOptions))
        button.bezelStyle = .rounded
        row.addArrangedSubview(button)
        return row
    }

    private func simpleCustomizePanel() -> NSView {
        let card = RoundedView(fill: productCardColor(), stroke: NSColor.separatorColor.withAlphaComponent(0.26), radius: 8)
        card.widthAnchor.constraint(equalToConstant: 500).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(compactPopupRow(title: "Display sleeps after", popupKey: "idle", titles: ["3 minutes", "5 minutes", "10 minutes", "15 minutes"], action: #selector(changeIdleDelay)))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(compactPopupRow(title: "Low battery alert", popupKey: "warning", titles: ["15%", "20%", "25%", "30%"], action: #selector(changeWarningLevel)))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(compactSwitchRow(title: "Keep Mac awake", switchKey: "keepAwake", action: #selector(switchKeepAwake)))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(compactSwitchRow(title: "Allow lid closed", switchKey: "lidClosed", action: #selector(switchLidClosedMode)))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(compactSwitchRow(title: "Battery alerts", switchKey: "batteryAlerts", action: #selector(switchBatteryAlerts)))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(compactButtonRow(title: "Notification banners", buttonKey: "productNotification", action: #selector(notificationPermissionAction)))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(compactButtonRow(title: "Test alert sound", buttonTitle: "Test", buttonKey: "testAlert", action: #selector(testBatteryAlert)))

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func compactPopupRow(title: String, popupKey: String, titles: [String], action: Selector) -> NSView {
        let row = compactRow(title: title)
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: titles)
        popup.target = self
        popup.action = action
        popup.controlSize = .regular
        popups[popupKey] = popup
        row.addArrangedSubview(popup)
        return row
    }

    private func compactSwitchRow(title: String, switchKey: String, action: Selector) -> NSView {
        let row = compactRow(title: title)
        let switchControl = NSSwitch()
        switchControl.target = self
        switchControl.action = action
        switches[switchKey] = switchControl
        row.addArrangedSubview(switchControl)
        return row
    }

    private func compactButtonRow(title: String, buttonTitle: String = "Allow", buttonKey: String, action: Selector) -> NSView {
        let row = compactRow(title: title)
        let button = NSButton(title: buttonTitle, target: self, action: action)
        button.bezelStyle = .rounded
        actionButtons[buttonKey] = button
        row.addArrangedSubview(button)
        return row
    }

    private func compactRow(title: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.addArrangedSubview(label(title, size: 13, weight: .medium))
        row.addArrangedSubview(spacer())
        return row
    }

    private func productHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 700).isActive = true

        row.addArrangedSubview(symbolCircle("shield.fill", tone: .blue, size: 34))

        let names = NSStackView()
        names.orientation = .vertical
        names.spacing = 1
        names.addArrangedSubview(label("Vibecoding Guard", size: 14, weight: .semibold))
        names.addArrangedSubview(label("Step away without babysitting the Mac", size: 11, weight: .medium, color: .secondaryLabelColor))
        row.addArrangedSubview(names)
        row.addArrangedSubview(spacer())

        let battery = label("Battery", size: 12, weight: .medium, color: .secondaryLabelColor)
        statusLabels["productBatteryLine"] = battery
        row.addArrangedSubview(battery)
        return row
    }

    private func productHeroCard() -> NSView {
        let card = RoundedView(fill: productCardColor(), stroke: NSColor.separatorColor.withAlphaComponent(0.32), radius: 8)
        card.widthAnchor.constraint(equalToConstant: 700).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 9
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 17, left: 34, bottom: 18, right: 34)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let pill = dynamicPill(key: "productPill", text: "Checking", tone: .neutral)
        stack.addArrangedSubview(pill)

        let title = label("Your Mac will keep working.", size: 26, weight: .bold)
        title.alignment = .center
        title.maximumNumberOfLines = 2
        statusLabels["productHeroTitle"] = title
        stack.addArrangedSubview(title)

        let message = label(
            "Guard keeps long jobs alive while the display can rest, then gets your attention before battery becomes the problem.",
            size: 13,
            color: .secondaryLabelColor
        )
        message.alignment = .center
        message.maximumNumberOfLines = 3
        message.widthAnchor.constraint(lessThanOrEqualToConstant: 520).isActive = true
        statusLabels["productHeroMessage"] = message
        stack.addArrangedSubview(message)

        let guardButton = NSButton(title: "Turn Off Guard", target: self, action: #selector(toggleMasterGuardButton))
        guardButton.bezelStyle = .rounded
        guardButton.controlSize = .large
        actionButtons["productGuardToggle"] = guardButton
        stack.addArrangedSubview(guardButton)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func productPermissionCard() -> NSView {
        let stack = productCardStack(
            title: "Approvals",
            subtitle: "Guard asks macOS only for the small pieces it needs."
        )
        stack.addArrangedSubview(productPermissionRow(
            symbol: "battery.75",
            title: "Keep awake on battery",
            body: "Lets long jobs continue after you stop using the keyboard.",
            statusKey: "productBatteryModeStatus",
            buttonKey: "productBatteryMode",
            action: #selector(enableBatterySleepSetting)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(productPermissionRow(
            symbol: "bell.badge.fill",
            title: "Battery alert banners",
            body: "Optional. Sound and voice alerts still work without banners.",
            statusKey: "productNotificationStatus",
            buttonKey: "productNotification",
            action: #selector(notificationPermissionAction)
        ))
        return productCard(stack)
    }

    private func productJourneyCard() -> NSView {
        let stack = productCardStack(
            title: "Before you leave",
            subtitle: "The short checklist for a long-running agent, build, download, or remote session."
        )
        stack.addArrangedSubview(productJourneyRow(
            symbol: "macbook",
            title: "Keep the lid open",
            body: "macOS can still sleep a notebook when the lid closes. Let the display rest instead.",
            statusKey: "journeyLid"
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(productJourneyRow(
            symbol: "display",
            title: "Let the display go dark",
            body: "The screen can turn off after quiet time while the Mac keeps working.",
            statusKey: "journeyDisplay"
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(productJourneyRow(
            symbol: "battery.100",
            title: "Power looks safe",
            body: "Guard will warn before low battery, but plugging in is still best for overnight work.",
            statusKey: "journeyPower"
        ))
        return productCard(stack)
    }

    private func productJourneyRow(
        symbol: String,
        title: String,
        body: String,
        statusKey: String
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.addArrangedSubview(symbolCircle(symbol, tone: .blue, size: 30))

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 3
        text.alignment = .leading
        text.addArrangedSubview(label(title, size: 13, weight: .semibold))
        let bodyLabel = label(body, size: 12, color: .secondaryLabelColor)
        bodyLabel.maximumNumberOfLines = 2
        text.addArrangedSubview(bodyLabel)
        row.addArrangedSubview(text)
        row.addArrangedSubview(spacer(width: 10))

        let status = label("Checking", size: 12, weight: .semibold, color: .secondaryLabelColor)
        statusLabels[statusKey] = status
        row.addArrangedSubview(status)
        return row
    }

    private func productPermissionRow(
        symbol: String,
        title: String,
        body: String,
        statusKey: String,
        buttonKey: String,
        action: Selector
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.addArrangedSubview(symbolCircle(symbol, tone: .neutral, size: 30))

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 3
        text.alignment = .leading
        text.addArrangedSubview(label(title, size: 13, weight: .semibold))
        let bodyLabel = label(body, size: 12, color: .secondaryLabelColor)
        bodyLabel.maximumNumberOfLines = 2
        text.addArrangedSubview(bodyLabel)
        row.addArrangedSubview(text)
        row.addArrangedSubview(spacer(width: 10))

        let status = label("Checking", size: 12, weight: .medium, color: .secondaryLabelColor)
        statusLabels[statusKey] = status
        row.addArrangedSubview(status)

        let button = NSButton(title: "Set Up", target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.setContentHuggingPriority(.required, for: .horizontal)
        actionButtons[buttonKey] = button
        row.addArrangedSubview(button)
        return row
    }

    private func productOptionsDisclosure() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 700).isActive = true

        let button = NSButton(
            title: advancedExpanded ? "Hide Options" : "Options",
            target: self,
            action: #selector(toggleAdvancedOptions)
        )
        button.bezelStyle = .rounded
        row.addArrangedSubview(button)
        row.addArrangedSubview(label("Fine-tune timing and individual protections.", size: 12, color: .secondaryLabelColor))
        row.addArrangedSubview(spacer())
        return row
    }

    private func productAdvancedOptions() -> NSView {
        let stack = productCardStack(
            title: "Fine-tune",
            subtitle: "Useful after the basic step-away journey is already working."
        )
        stack.addArrangedSubview(productSwitchRow(
            symbol: "bolt.fill",
            title: "Keep work awake",
            body: "Prevent idle sleep while Guard is on.",
            switchKey: "keepAwake",
            action: #selector(switchKeepAwake)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(productSwitchRow(
            symbol: "display",
            title: "Let display rest",
            body: "Turn the screen off after idle time.",
            switchKey: "displayIdle",
            action: #selector(switchDisplayIdle)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(productSwitchRow(
            symbol: "bell.fill",
            title: "Battery alerts",
            body: "Play sound and voice warnings when battery is low.",
            switchKey: "batteryAlerts",
            action: #selector(switchBatteryAlerts)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(popupRow(
            symbol: "clock",
            title: "Screen rest delay",
            body: "Wait this long after no keyboard or mouse activity.",
            popupKey: "idle",
            titles: ["3 minutes", "5 minutes", "10 minutes", "15 minutes"],
            action: #selector(changeIdleDelay)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(popupRow(
            symbol: "battery.25",
            title: "Low battery warning",
            body: "First reminder to plug in power.",
            popupKey: "warning",
            titles: ["15%", "20%", "25%", "30%"],
            action: #selector(changeWarningLevel)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(popupRow(
            symbol: "exclamationmark.triangle.fill",
            title: "Critical warning",
            body: "Stronger repeat warning when power is almost gone.",
            popupKey: "critical",
            titles: ["5%", "10%", "15%"],
            action: #selector(changeCriticalLevel)
        ))
        return productCard(stack)
    }

    private func productSwitchRow(
        symbol: String,
        title: String,
        body: String,
        switchKey: String,
        action: Selector
    ) -> NSView {
        let row = baseRow(symbol: symbol, tone: .blue, title: title, body: body)
        let switchControl = NSSwitch()
        switchControl.target = self
        switchControl.action = action
        switches[switchKey] = switchControl
        row.addArrangedSubview(switchControl)
        return row
    }

    private func productFooter(onboarding: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = productBackgroundColor().cgColor
        container.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let rule = NSBox()
        rule.boxType = .separator
        rule.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let privacy = label("Local only. No account. No file, Reminders, or calendar access.", size: 11, weight: .medium, color: .secondaryLabelColor)
        row.addArrangedSubview(privacy)
        row.addArrangedSubview(spacer())

        let test = NSButton(title: "Test Alert", target: self, action: #selector(testBatteryAlert))
        test.bezelStyle = .rounded
        row.addArrangedSubview(test)

        let sleep = NSButton(title: "Sleep Display", target: self, action: #selector(displaySleepNow))
        sleep.bezelStyle = .rounded
        row.addArrangedSubview(sleep)

        let primary = NSButton(title: onboarding ? "Finish Setup" : "Done", target: self, action: #selector(primaryProductAction))
        primary.bezelStyle = .rounded
        primary.keyEquivalent = "\r"
        actionButtons["productPrimary"] = primary
        row.addArrangedSubview(primary)

        container.addSubview(rule)
        container.addSubview(row)
        NSLayoutConstraint.activate([
            rule.topAnchor.constraint(equalTo: container.topAnchor),
            rule.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 30),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -30),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])
        return container
    }

    private func productCardStack(title: String, subtitle: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.addArrangedSubview(label(title, size: 16, weight: .bold))
        let subtitleLabel = label(subtitle, size: 12, color: .secondaryLabelColor)
        subtitleLabel.maximumNumberOfLines = 2
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(separator())
        return stack
    }

    private func productCard(_ content: NSView) -> NSView {
        let card = RoundedView(fill: productCardColor(), stroke: NSColor.separatorColor.withAlphaComponent(0.28), radius: 8)
        card.widthAnchor.constraint(equalToConstant: 700).isActive = true
        card.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func productBackgroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.08, alpha: 1)
            }
            return NSColor(calibratedWhite: 0.965, alpha: 1)
        }
    }

    private func productCardColor() -> NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 1)
            }
            return NSColor(calibratedWhite: 1.0, alpha: 1)
        }
    }

    private func sidebarView(onboarding: Bool) -> NSView {
        let sidebar = RoundedView(fill: subtleBlueBackground(), radius: 0)
        sidebar.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor),
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor)
        ])

        let brand = NSStackView()
        brand.orientation = .horizontal
        brand.spacing = 10
        brand.alignment = .centerY
        brand.addArrangedSubview(symbolCircle("shield", tone: .blue, size: 34))
        let brandText = NSStackView()
        brandText.orientation = .vertical
        brandText.spacing = 1
        brandText.addArrangedSubview(label("Vibecoding Guard", size: 15, weight: .bold))
        brandText.addArrangedSubview(label("Local Mac utility", size: 11, weight: .medium, color: .secondaryLabelColor))
        brand.addArrangedSubview(brandText)
        stack.addArrangedSubview(brand)

        let hero = label(
            onboarding ? "Keep work alive. Let the screen rest." : "Your Mac is ready for long-running work.",
            size: 25,
            weight: .bold
        )
        hero.maximumNumberOfLines = 0
        stack.addArrangedSubview(hero)

        let copy = label(
            "For Codex sessions, remote agents, builds, downloads, and anything else that should keep going when you step away.",
            size: 13,
            color: .secondaryLabelColor
        )
        copy.maximumNumberOfLines = 0
        stack.addArrangedSubview(copy)

        stack.addArrangedSubview(sidebarBatteryBlock())
        stack.addArrangedSubview(sidebarChecklist())
        stack.addArrangedSubview(spacer())

        let privacy = label("Runs locally. No cloud account. No Reminders or file access required.", size: 11, weight: .medium, color: .secondaryLabelColor)
        privacy.maximumNumberOfLines = 0
        stack.addArrangedSubview(privacy)

        return sidebar
    }

    private func sidebarBatteryBlock() -> NSView {
        let box = RoundedView(fill: NSColor.controlBackgroundColor.withAlphaComponent(0.72), stroke: NSColor.separatorColor.withAlphaComponent(0.55))
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 15, left: 16, bottom: 15, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = label("Battery", size: 12, weight: .semibold, color: .secondaryLabelColor)
        let percent = label("Checking", size: 34, weight: .bold)
        let detail = label("Reading current power state...", size: 12, color: .secondaryLabelColor)
        detail.maximumNumberOfLines = 0
        statusLabels["batteryPercentLarge"] = percent
        statusLabels["batteryDetail"] = detail

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(percent)
        stack.addArrangedSubview(detail)
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        return box
    }

    private func sidebarChecklist() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 11
        stack.alignment = .leading
        stack.addArrangedSubview(sidebarStep(symbol: "bolt.fill", title: "Background work", key: "stepWork"))
        stack.addArrangedSubview(sidebarStep(symbol: "display", title: "Display rest", key: "stepDisplay"))
        stack.addArrangedSubview(sidebarStep(symbol: "bell.fill", title: "Battery warnings", key: "stepBattery"))
        stack.addArrangedSubview(sidebarStep(symbol: "lock.open.fill", title: "Approvals", key: "stepApprovals"))
        return stack
    }

    private func sidebarStep(symbol: String, title: String, key: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 9
        row.alignment = .centerY
        row.addArrangedSubview(symbolCircle(symbol, tone: .neutral, size: 26))

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 1
        text.addArrangedSubview(label(title, size: 12, weight: .semibold))
        let status = label("Checking...", size: 11, color: .secondaryLabelColor)
        statusLabels[key] = status
        text.addArrangedSubview(status)
        row.addArrangedSubview(text)
        return row
    }

    private func mainContentView(onboarding: Bool) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 0
        container.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 30, bottom: 18, right: 30)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(mainHeader(onboarding: onboarding))
        stack.addArrangedSubview(setupPanel())
        stack.addArrangedSubview(tuningPanel())

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: 634)
        ])
        scroll.documentView = document
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        container.addArrangedSubview(scroll)
        container.addArrangedSubview(actionBarContainer(onboarding: onboarding))
        return container
    }

    private func mainHeader(onboarding: Bool) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 16

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 6
        let title = label(onboarding ? "Start with the two approvals" : "Control Center", size: 24, weight: .bold)
        let summary = label(
            onboarding
                ? "After setup, Guard can keep work running on battery, let the display turn off, and warn you before the battery gets too low."
                : "See what is protected, change timing, or test alerts. Everything here runs on this Mac.",
            size: 13,
            color: .secondaryLabelColor
        )
        summary.maximumNumberOfLines = 0
        statusLabels["mainSummary"] = summary
        text.addArrangedSubview(title)
        text.addArrangedSubview(summary)

        row.addArrangedSubview(text)
        row.addArrangedSubview(spacer())
        let pill = dynamicPill(key: "heroPill", text: "Checking", tone: .neutral)
        row.addArrangedSubview(pill)
        return row
    }

    private func setupPanel() -> NSView {
        let stack = panelStack(title: "Protection setup", subtitle: "These are the behaviors that make Guard useful during long work sessions.")
        stack.addArrangedSubview(protectionRow(
            symbol: "bolt.fill",
            title: "Keep background work alive",
            body: "Prevents idle sleep so agents, builds, and remote sessions keep running when you step away.",
            controlKey: "keepAwake",
            action: #selector(windowToggleKeepAwake)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(protectionRow(
            symbol: "display",
            title: "Let the display rest",
            body: "Turns the screen off after quiet time while the computer keeps working.",
            controlKey: "displayIdle",
            action: #selector(windowToggleDisplayIdle)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(protectionRow(
            symbol: "bell.fill",
            title: "Warn before low battery",
            body: "Plays a sound, speaks a short warning, and can show a notification banner.",
            controlKey: "batteryAlerts",
            action: #selector(windowToggleBatteryAlerts)
        ))
        return boxed(stack)
    }

    private func protectionRow(
        symbol: String,
        title: String,
        body: String,
        controlKey: String,
        action: Selector
    ) -> NSView {
        let row = baseRow(symbol: symbol, tone: .blue, title: title, body: body)
        let toggle = NSButton(checkboxWithTitle: "Enabled", target: self, action: action)
        toggle.font = .systemFont(ofSize: 12, weight: .medium)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        controls[controlKey] = toggle
        row.addArrangedSubview(toggle)
        return row
    }

    private func tuningPanel() -> NSView {
        let stack = panelStack(title: "Timing and permissions", subtitle: "A small setup checklist, with the system prompts separated from everyday controls.")
        stack.addArrangedSubview(permissionActionRow(
            symbol: "bell.badge.fill",
            title: "Notification banners",
            body: "Optional. Used only when battery alerts are enabled.",
            key: "notification",
            action: #selector(notificationPermissionAction)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(permissionActionRow(
            symbol: "battery.75",
            title: "Battery work mode",
            body: "Requires administrator approval so macOS will not idle-sleep on battery.",
            key: "batterySleep",
            action: #selector(enableBatterySleepSetting)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(popupRow(
            symbol: "clock",
            title: "Screen rest delay",
            body: "How long to wait after no keyboard or mouse activity.",
            popupKey: "idle",
            titles: ["3 minutes", "5 minutes", "10 minutes", "15 minutes"],
            action: #selector(changeIdleDelay)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(popupRow(
            symbol: "battery.25",
            title: "Low battery warning",
            body: "The first reminder to plug in power.",
            popupKey: "warning",
            titles: ["15%", "20%", "25%", "30%"],
            action: #selector(changeWarningLevel)
        ))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(popupRow(
            symbol: "exclamationmark.triangle.fill",
            title: "Critical battery warning",
            body: "The stronger repeat warning when power is almost gone.",
            popupKey: "critical",
            titles: ["5%", "10%", "15%"],
            action: #selector(changeCriticalLevel)
        ))
        return boxed(stack)
    }

    private func permissionActionRow(
        symbol: String,
        title: String,
        body: String,
        key: String,
        action: Selector
    ) -> NSView {
        let row = baseRow(symbol: symbol, tone: .neutral, title: title, body: body)
        let button = NSButton(title: "Checking", target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.setContentHuggingPriority(.required, for: .horizontal)
        actionButtons[key] = button
        row.addArrangedSubview(button)
        return row
    }

    private func popupRow(
        symbol: String,
        title: String,
        body: String,
        popupKey: String,
        titles: [String],
        action: Selector
    ) -> NSView {
        let row = baseRow(symbol: symbol, tone: .neutral, title: title, body: body)
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: titles)
        popup.target = self
        popup.action = action
        popup.controlSize = .regular
        popup.setContentHuggingPriority(.required, for: .horizontal)
        popups[popupKey] = popup
        row.addArrangedSubview(popup)
        return row
    }

    private func actionsPanel(onboarding: Bool) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let test = NSButton(title: "Test Alert", target: self, action: #selector(testBatteryAlert))
        test.bezelStyle = .rounded
        let sleep = NSButton(title: "Sleep Display Now", target: self, action: #selector(displaySleepNow))
        sleep.bezelStyle = .rounded
        let settings = NSButton(title: "Battery Settings", target: self, action: #selector(openPowerSettings))
        settings.bezelStyle = .rounded
        let finish = NSButton(title: onboarding ? "Finish Setup" : "Done", target: self, action: #selector(finishOnboarding))
        finish.bezelStyle = .rounded
        finish.keyEquivalent = "\r"

        row.addArrangedSubview(test)
        row.addArrangedSubview(sleep)
        row.addArrangedSubview(settings)
        row.addArrangedSubview(spacer())
        row.addArrangedSubview(finish)
        return row
    }

    private func actionBarContainer(onboarding: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.heightAnchor.constraint(equalToConstant: 58).isActive = true

        let rule = NSBox()
        rule.boxType = .separator
        rule.translatesAutoresizingMaskIntoConstraints = false

        let row = actionsPanel(onboarding: onboarding)
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rule)
        container.addSubview(row)
        NSLayoutConstraint.activate([
            rule.topAnchor.constraint(equalTo: container.topAnchor),
            rule.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 30),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -30),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])
        return container
    }

    private func baseRow(symbol: String, tone: Tone, title: String, body: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.addArrangedSubview(symbolCircle(symbol, tone: tone, size: 32))

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 3
        text.alignment = .leading
        let titleLabel = label(title, size: 13, weight: .semibold)
        let bodyLabel = label(body, size: 12, color: .secondaryLabelColor)
        bodyLabel.maximumNumberOfLines = 0
        text.addArrangedSubview(titleLabel)
        text.addArrangedSubview(bodyLabel)
        row.addArrangedSubview(text)
        row.addArrangedSubview(spacer(width: 8))
        return row
    }

    private func panelStack(title: String, subtitle: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 17, left: 18, bottom: 17, right: 18)

        let titleLabel = label(title, size: 16, weight: .bold)
        let subtitleLabel = label(subtitle, size: 12, color: .secondaryLabelColor)
        subtitleLabel.maximumNumberOfLines = 0
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(separator())
        return stack
    }

    private func boxed(_ content: NSView) -> NSView {
        let box = RoundedView(fill: NSColor.controlBackgroundColor, stroke: NSColor.separatorColor.withAlphaComponent(0.45))
        box.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: box.topAnchor),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            box.widthAnchor.constraint(equalToConstant: 634)
        ])
        return box
    }

    private func separator() -> NSView {
        let view = NSBox()
        view.boxType = .separator
        return view
    }

    private func dynamicPill(key: String, text: String, tone: Tone) -> NSView {
        let colors = toneColors(tone)
        let box = RoundedView(fill: colors.background, stroke: nil, radius: 8)
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let textLabel = label(text, size: 12, weight: .semibold, color: colors.foreground)
        stack.addArrangedSubview(textLabel)
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        statusLabels[key] = textLabel
        pillViews[key] = box
        return box
    }

    private func pill(_ text: String, tone: Tone) -> NSView {
        let box = RoundedView(fill: toneColors(tone).background, stroke: nil, radius: 8)
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let textLabel = label(text, size: 12, weight: .semibold, color: toneColors(tone).foreground)
        stack.addArrangedSubview(textLabel)
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        return box
    }

    private func symbolCircle(_ symbol: String, tone: Tone, size: CGFloat) -> NSView {
        let colors = toneColors(tone)
        let box = RoundedView(fill: colors.background, stroke: nil, radius: size / 2)
        box.widthAnchor.constraint(equalToConstant: size).isActive = true
        box.heightAnchor.constraint(equalToConstant: size).isActive = true

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.contentTintColor = colors.foreground
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        box.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: size * 0.52),
            imageView.heightAnchor.constraint(equalToConstant: size * 0.52)
        ])
        return box
    }

    private func spacer(width: CGFloat? = nil) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if let width {
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
        }
        return view
    }

    private func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.lineBreakMode = .byWordWrapping
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    private func subtleBlueBackground() -> NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1)
            }
            return NSColor(calibratedRed: 0.92, green: 0.95, blue: 0.97, alpha: 1)
        }
    }

    private func toneColors(_ tone: Tone) -> (background: NSColor, foreground: NSColor) {
        switch tone {
        case .good:
            return (NSColor.systemGreen.withAlphaComponent(0.16), NSColor.systemGreen)
        case .warning:
            return (NSColor.systemOrange.withAlphaComponent(0.17), NSColor.systemOrange)
        case .danger:
            return (NSColor.systemRed.withAlphaComponent(0.15), NSColor.systemRed)
        case .blue:
            return (NSColor.controlAccentColor.withAlphaComponent(0.16), NSColor.controlAccentColor)
        case .neutral:
            return (NSColor.secondaryLabelColor.withAlphaComponent(0.12), NSColor.secondaryLabelColor)
        }
    }

    private func refreshWindow() {
        controls["keepAwake"]?.state = config.keepAwakeEnabled ? .on : .off
        controls["keepAwake"]?.title = config.keepAwakeEnabled ? "Enabled" : "Paused"
        controls["displayIdle"]?.state = config.displayIdleSleepEnabled ? .on : .off
        controls["displayIdle"]?.title = config.displayIdleSleepEnabled ? "Enabled" : "Paused"
        controls["batteryAlerts"]?.state = config.batteryAlertsEnabled ? .on : .off
        controls["batteryAlerts"]?.title = config.batteryAlertsEnabled ? "Enabled" : "Paused"
        switches["master"]?.state = masterGuardEnabled ? .on : .off
        switches["keepAwake"]?.state = config.keepAwakeEnabled ? .on : .off
        switches["displayIdle"]?.state = config.displayIdleSleepEnabled ? .on : .off
        switches["batteryAlerts"]?.state = config.batteryAlertsEnabled ? .on : .off
        switches["lidClosed"]?.state = config.lidClosedModeEnabled ? .on : .off

        if let battery = lastBatteryInfo {
            statusLabels["batteryPercentLarge"]?.stringValue = "\(battery.percent)%"
            statusLabels["batteryDetail"]?.stringValue = friendlyBatteryStatus(battery.status)
            statusLabels["productBatteryLine"]?.stringValue = "\(battery.percent)% \(friendlyBatteryStatus(battery.status))"
            statusLabels["journeyPower"]?.stringValue = battery.percent <= config.warningPercent && battery.isDischarging ? "Plug in" : "Good"
            statusLabels["journeyPower"]?.textColor = battery.percent <= config.warningPercent && battery.isDischarging
                ? toneColors(.warning).foreground
                : toneColors(.good).foreground
        } else {
            statusLabels["batteryPercentLarge"]?.stringValue = "Checking"
            statusLabels["batteryDetail"]?.stringValue = "Reading current power state..."
            statusLabels["productBatteryLine"]?.stringValue = "Checking battery"
            statusLabels["journeyPower"]?.stringValue = "Checking"
            statusLabels["journeyPower"]?.textColor = toneColors(.neutral).foreground
        }

        statusLabels["journeyLid"]?.stringValue = "Open"
        statusLabels["journeyLid"]?.textColor = toneColors(.good).foreground
        statusLabels["journeyDisplay"]?.stringValue = config.displayIdleSleepEnabled
            ? "\(config.idleDisplaySeconds / 60) min"
            : "Off"
        statusLabels["journeyDisplay"]?.textColor = config.displayIdleSleepEnabled
            ? toneColors(.good).foreground
            : toneColors(.neutral).foreground

        statusLabels["stepWork"]?.stringValue =
            caffeinateProcess?.isRunning == true ? "Active" : "Paused"
        statusLabels["stepDisplay"]?.stringValue =
            config.displayIdleSleepEnabled ? "\(config.idleDisplaySeconds / 60) min idle" : "Paused"
        statusLabels["stepBattery"]?.stringValue =
            config.batteryAlertsEnabled ? "\(config.warningPercent)% / \(config.criticalPercent)%" : "Paused"
        statusLabels["stepApprovals"]?.stringValue = approvalSummary()

        let health = protectionHealth()
        statusLabels["heroPill"]?.stringValue = health.title
        statusLabels["heroPill"]?.textColor = toneColors(health.tone).foreground
        pillViews["heroPill"]?.update(fill: toneColors(health.tone).background)

        let product = productHealth()
        statusLabels["productPill"]?.stringValue = product.pill
        statusLabels["productPill"]?.textColor = toneColors(product.tone).foreground
        pillViews["productPill"]?.update(fill: toneColors(product.tone).background)
        statusLabels["productHeroTitle"]?.stringValue = product.title
        statusLabels["productHeroMessage"]?.stringValue = product.message

        statusLabels["mainSummary"]?.stringValue = health.summary
        refreshNotificationButton()
        refreshBatterySleepButton()
        refreshProductPermissionButtons()
        refreshPopups()
    }

    private func refreshNotificationButton() {
        guard let button = actionButtons["notification"] else {
            return
        }
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            button.title = "Allowed"
            button.isEnabled = false
        case .denied:
            button.title = "Open Settings"
            button.isEnabled = true
        case .notDetermined:
            button.title = "Allow Notifications"
            button.isEnabled = true
        @unknown default:
            button.title = "Open Settings"
            button.isEnabled = true
        }
    }

    private func refreshBatterySleepButton() {
        guard let button = actionButtons["batterySleep"] else {
            return
        }
        if lastPowerSettings?.batterySleepMinutes == 0 {
            button.title = "Enabled"
            button.isEnabled = false
        } else {
            button.title = "Allow Admin Change"
            button.isEnabled = true
        }
    }

    private func refreshProductPermissionButtons() {
        if let status = statusLabels["productBatteryModeStatus"],
           let button = actionButtons["productBatteryMode"] {
            if lastPowerSettings?.batterySleepMinutes == 0 {
                status.stringValue = "Ready"
                status.textColor = toneColors(.good).foreground
                button.title = "Ready"
                button.isEnabled = false
            } else {
                status.stringValue = "Needs approval"
                status.textColor = toneColors(.warning).foreground
                button.title = "Enable"
                button.isEnabled = true
            }
        }

        if let status = statusLabels["productNotificationStatus"],
           let button = actionButtons["productNotification"] {
            switch notificationStatus {
            case .authorized, .provisional, .ephemeral:
                status.stringValue = "Ready"
                status.textColor = toneColors(.good).foreground
                button.title = "Ready"
                button.isEnabled = false
            case .denied:
                status.stringValue = "Off"
                status.textColor = toneColors(.neutral).foreground
                button.title = "Open Settings"
                button.isEnabled = true
            case .notDetermined:
                status.stringValue = "Optional"
                status.textColor = toneColors(.neutral).foreground
                button.title = "Allow"
                button.isEnabled = true
            @unknown default:
                status.stringValue = "Unknown"
                status.textColor = toneColors(.neutral).foreground
                button.title = "Open Settings"
                button.isEnabled = true
            }
        }

        if let primary = actionButtons["productPrimary"] {
            primary.title = productPrimaryTitle()
        }
        if let primary = actionButtons["simplePrimary"] {
            primary.title = simplePrimaryTitle()
        }
        if let guardButton = actionButtons["productGuardToggle"] {
            guardButton.title = masterGuardEnabled ? "Turn Off Guard" : "Turn On Guard"
        }
    }

    private func refreshPopups() {
        selectPopup(popups["idle"], value: config.idleDisplaySeconds / 60, values: [3, 5, 10, 15])
        selectPopup(popups["warning"], value: config.warningPercent, values: [15, 20, 25, 30])
        selectPopup(popups["critical"], value: config.criticalPercent, values: [5, 10, 15])
    }

    private func selectPopup(_ popup: NSPopUpButton?, value: Int, values: [Int]) {
        guard let popup else {
            return
        }
        let index = values.firstIndex(of: value) ?? 0
        popup.selectItem(at: index)
    }

    private func approvalSummary() -> String {
        var parts: [String] = []
        if lastPowerSettings?.batterySleepMinutes == 0 {
            parts.append("battery ready")
        } else {
            parts.append("battery approval needed")
        }
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            parts.append("notifications ready")
        case .denied:
            parts.append("notifications denied")
        case .notDetermined:
            parts.append("notifications optional")
        @unknown default:
            parts.append("notifications unknown")
        }
        return parts.joined(separator: ", ")
    }

    private var masterGuardEnabled: Bool {
        config.keepAwakeEnabled && config.displayIdleSleepEnabled && config.batteryAlertsEnabled
    }

    private func setMasterGuard(enabled: Bool) {
        config.keepAwakeEnabled = enabled
        config.displayIdleSleepEnabled = enabled
        config.batteryAlertsEnabled = enabled
        config.lidClosedModeEnabled = enabled
        applyKeepAwakeState()
    }

    private func productHealth() -> (pill: String, title: String, message: String, tone: Tone) {
        if config.keepAwakeEnabled && caffeinateProcess?.isRunning != true {
            return (
                "Needs attention",
                "Guard needs attention",
                "The keep-awake helper is not running. Guard will keep trying, but long jobs may not be protected yet.",
                .danger
            )
        }
        if needsSetupHelp {
            return (
                "Setup",
                "Allow & turn on",
                "macOS will ask once so Guard can keep working with the lid closed.",
                .warning
            )
        }
        if !masterGuardEnabled {
            return (
                "Off",
                "Guard is Off",
                "Turn it on before you step away from long-running work.",
                .neutral
            )
        }
            return (
                "On",
                "Guard is On",
                config.lidClosedModeEnabled
                    ? "You can close the lid. Keep it on a desk, not in a bag."
                    : "Keep the lid open. Long jobs keep running while the display can sleep.",
                .good
            )
    }

    private func simplePrimaryTitle() -> String {
        if needsSetupHelp {
            return "Allow & Turn On"
        }
        return masterGuardEnabled ? "Turn Off" : "Turn On"
    }

    private func productPrimaryTitle() -> String {
        if needsSetupHelp {
            return "Allow & Turn On"
        }
        return "Done"
    }

    private func protectionHealth() -> (title: String, summary: String, tone: Tone) {
        if config.keepAwakeEnabled && caffeinateProcess?.isRunning != true {
            return (
                "Needs attention",
                "Keep-awake is enabled, but the helper is not running. Guard will keep trying to restart it.",
                .danger
            )
        }
        if lastPowerSettings?.batterySleepMinutes != 0 {
            return (
                "Setup needed",
                "Approve Battery work mode so long jobs can continue on battery power.",
                .warning
            )
        }
        if notificationStatus == .notDetermined && config.batteryAlertsEnabled {
            return (
                "Almost ready",
                "Battery protection is active. Allow notifications if you want banner alerts too.",
                .warning
            )
        }
        if notificationStatus == .denied && config.batteryAlertsEnabled {
            return (
                "Banners off",
                "Sound and voice alerts can still work, but macOS notification banners are disabled.",
                .neutral
            )
        }
        if config.keepAwakeEnabled && config.displayIdleSleepEnabled && config.batteryAlertsEnabled {
            return (
                "Guarding",
                "Your Mac can keep working, the display can rest, and battery alerts are armed.",
                .good
            )
        }
        return (
            "Partly active",
            "Some protections are paused. Turn on the behaviors you want for long work sessions.",
            .neutral
        )
    }

    private func friendlyBatteryStatus(_ status: String) -> String {
        let lower = status.lowercased()
        if lower.contains("charging") {
            return "Charging"
        }
        if lower.contains("discharging") {
            return "On battery"
        }
        if lower.contains("charged") || lower.contains("finishing") {
            return "Charged"
        }
        return status.capitalized
    }

    @objc private func windowToggleKeepAwake() {
        config.keepAwakeEnabled = controls["keepAwake"]?.state == .on
        applyKeepAwakeState()
        runChecks()
    }

    @objc private func windowToggleDisplayIdle() {
        config.displayIdleSleepEnabled = controls["displayIdle"]?.state == .on
        runChecks()
    }

    @objc private func windowToggleBatteryAlerts() {
        config.batteryAlertsEnabled = controls["batteryAlerts"]?.state == .on
        runChecks()
    }

    @objc private func toggleMasterGuard() {
        let enabled = switches["master"]?.state == .on
        setMasterGuard(enabled: enabled)
        setLidClosedMode(enabled: enabled)
        runChecks()
    }

    @objc private func toggleMasterGuardButton() {
        let enabled = !masterGuardEnabled
        setMasterGuard(enabled: enabled)
        setLidClosedMode(enabled: enabled)
        runChecks()
    }

    @objc private func simplePrimaryAction() {
        if needsSetupHelp {
            setMasterGuard(enabled: true)
            setLidClosedMode(enabled: true)
            if notificationStatus == .notDetermined {
                requestNotificationPermission()
            }
            config.onboardingCompleted = true
            runChecks()
            return
        }

        let enabled = !masterGuardEnabled
        setMasterGuard(enabled: enabled)
        setLidClosedMode(enabled: enabled)
        if enabled && notificationStatus == .notDetermined {
            requestNotificationPermission()
        }
        config.onboardingCompleted = true
        runChecks()
    }

    @objc private func switchKeepAwake() {
        config.keepAwakeEnabled = switches["keepAwake"]?.state == .on
        applyKeepAwakeState()
        runChecks()
    }

    @objc private func switchDisplayIdle() {
        config.displayIdleSleepEnabled = switches["displayIdle"]?.state == .on
        runChecks()
    }

    @objc private func switchBatteryAlerts() {
        config.batteryAlertsEnabled = switches["batteryAlerts"]?.state == .on
        runChecks()
    }

    @objc private func switchLidClosedMode() {
        let enabled = switches["lidClosed"]?.state == .on
        setLidClosedMode(enabled: enabled)
        runChecks()
    }

    @objc private func toggleAdvancedOptions() {
        advancedExpanded.toggle()
        let reopenOnboarding = !config.onboardingCompleted
        let oldWindow = controlWindow
        controlWindow = nil
        oldWindow?.close()
        showControlCenter(onboarding: reopenOnboarding)
    }

    @objc private func primaryProductAction() {
        if needsSetupHelp {
            setMasterGuard(enabled: true)
            setLidClosedMode(enabled: true)
            finishOnboarding()
            return
        }
        finishOnboarding()
    }

    @objc private func finishOnboarding() {
        config.onboardingCompleted = true
        controlWindow?.close()
    }

    @objc private func notificationPermissionAction() {
        switch notificationStatus {
        case .denied:
            openNotificationSettings()
        case .authorized, .provisional, .ephemeral:
            testBatteryAlert()
        case .notDetermined:
            requestNotificationPermission()
        @unknown default:
            openNotificationSettings()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshNotificationStatus()
                self?.refreshWindow()
            }
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func enableBatterySleepSetting() {
        let script = """
        do shell script "/usr/bin/pmset -b sleep 0" with administrator privileges with prompt "Allow Vibecoding Guard to keep long-running work alive on battery."
        """
        _ = runCommand("/usr/bin/osascript", ["-e", script])
        lastPowerSettings = readPowerSettings()
        refreshWindow()
    }

    private func setLidClosedMode(enabled: Bool) {
        config.lidClosedModeEnabled = enabled
        if enabled {
            guard lastPowerSettings?.sleepDisabled != true else {
                return
            }
        } else {
            guard lastPowerSettings?.sleepDisabled == true else {
                return
            }
        }

        let value = enabled ? "1" : "0"
        let command = enabled
            ? "/usr/bin/pmset -a sleep 0; /usr/bin/pmset -a disablesleep \(value)"
            : "/usr/bin/pmset -a disablesleep \(value)"
        let prompt = enabled
            ? "Allow Vibecoding Guard to keep working while the lid is closed. Keep the Mac on a desk, not in a bag."
            : "Allow Vibecoding Guard to turn off closed-lid work mode."
        let script = """
        do shell script "\(command)" with administrator privileges with prompt "\(appleScriptQuoted(prompt))"
        """
        _ = runCommand("/usr/bin/osascript", ["-e", script])
        lastPowerSettings = readPowerSettings()
    }

    @objc private func changeIdleDelay() {
        let values = [3, 5, 10, 15]
        let index = popups["idle"]?.indexOfSelectedItem ?? 1
        config.idleDisplaySeconds = values[min(max(index, 0), values.count - 1)] * 60
        runChecks()
    }

    @objc private func changeWarningLevel() {
        let values = [15, 20, 25, 30]
        let index = popups["warning"]?.indexOfSelectedItem ?? 1
        config.warningPercent = values[min(max(index, 0), values.count - 1)]
        if config.criticalPercent >= config.warningPercent {
            config.criticalPercent = max(5, config.warningPercent - 10)
        }
        runChecks()
    }

    @objc private func changeCriticalLevel() {
        let values = [5, 10, 15]
        let index = popups["critical"]?.indexOfSelectedItem ?? 1
        config.criticalPercent = values[min(max(index, 0), values.count - 1)]
        if config.criticalPercent >= config.warningPercent {
            config.warningPercent = min(30, config.criticalPercent + 10)
        }
        runChecks()
    }

    private func checkBattery() {
        guard let battery = readBatteryInfo() else {
            return
        }
        lastBatteryInfo = battery

        guard config.batteryAlertsEnabled, battery.isDischarging else {
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

    private func maybeSendBatteryAlert(
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

    private func sendBatteryAlert(title: String, message: String, critical: Bool) {
        sendUserNotification(title: title, message: message)

        if let sound = NSSound(named: critical ? "Sosumi" : "Glass") {
            sound.play()
        }
        speak(critical ? "Battery critical. Plug in power now." : "Battery low. Please plug in power.")
    }

    private func sendUserNotification(title: String, message: String) {
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

    private func displayNotificationFallback(title: String, message: String) {
        let safeTitle = appleScriptQuoted(title)
        let safeMessage = appleScriptQuoted(message)
        let script = "display notification \"\(safeMessage)\" with title \"\(safeTitle)\""
        _ = runCommand("/usr/bin/osascript", ["-e", script])
    }

    private func speak(_ text: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = [text]
        try? process.run()
    }

    private func appleScriptQuoted(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func checkDisplayIdle() {
        guard config.displayIdleSleepEnabled else {
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

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationStatus = settings.authorizationStatus
                self?.refreshWindow()
            }
        }
    }

    private func readBatteryInfo() -> BatteryInfo? {
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

    private func readPowerSettings() -> PowerSettings? {
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

    private func readIdleSeconds() -> Int? {
        let output = runCommand("/usr/sbin/ioreg", ["-c", "IOHIDSystem", "-r", "-d", "1"])
        let regex = try? NSRegularExpression(pattern: #""HIDIdleTime"\s*=\s*(\d+)"#)
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
    private func runCommand(_ path: String, _ arguments: [String]) -> String {
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
            NSLog("Vibecoding Guard: command failed \(path): \(error)")
            return ""
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

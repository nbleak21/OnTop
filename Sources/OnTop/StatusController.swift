// Copyright (c) 2026 OnTop contributors
// SPDX-License-Identifier: MIT

import AppKit
import ServiceManagement

/// Owns the menu-bar item, the readers, the refresh timer, and the dropdown.
/// Selecting a stat in the dropdown promotes it to the menu-bar slot.
final class StatusController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let readers: [StatReader]
    private let defaults = UserDefaults.standard

    private var primaryID: String
    private var interval: TimeInterval
    private var timer: Timer?

    private var latest: [String: StatReading] = [:]
    private var rowItems: [String: NSMenuItem] = [:]
    private var intervalItems: [NSMenuItem] = []
    private var launchItem: NSMenuItem?

    private let intervalOptions: [TimeInterval] = [1, 2, 5]

    override init() {
        readers = [
            MemoryReader(),
            CPUReader(),
            GPUReader(),
            PowerReader(),
            TemperatureReader(),
            DiskReader(),
            NetworkReader(),
            FPSReader(),
        ]
        primaryID = defaults.string(forKey: "primaryID") ?? "ram"
        let saved = defaults.double(forKey: "interval")
        interval = saved > 0 ? saved : 2.0

        super.init()

        if !readers.contains(where: { $0.id == primaryID }) {
            primaryID = readers.first?.id ?? "ram"
        }
        statusItem.button?.imagePosition = .imageLeading
        buildMenu()
        tick()
        startTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func tick() {
        for reader in readers {
            latest[reader.id] = reader.sample()
        }
        updateBar()
        updateMenuValues()
    }

    // MARK: - Menu-bar slot

    private func updateBar() {
        guard
            let button = statusItem.button,
            let reader = readers.first(where: { $0.id == primaryID }),
            let reading = latest[primaryID]
        else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let image = NSImage(systemSymbolName: reader.symbolName, accessibilityDescription: reader.name)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image

        // Fully monospaced so digits, padding spaces, and unit letters are all
        // the same width — the menu-bar slot never jitters as values change.
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        button.attributedTitle = NSAttributedString(
            string: " " + reading.barText,
            attributes: [.font: font]
        )
    }

    // MARK: - Dropdown

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        for reader in readers {
            let item = NSMenuItem(
                title: reader.name,
                action: #selector(selectPrimary(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = reader.id
            item.image = NSImage(systemSymbolName: reader.symbolName, accessibilityDescription: nil)
            rowItems[reader.id] = item
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let intervalParent = NSMenuItem(title: "Update Interval", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for option in intervalOptions {
            let seconds = Int(option)
            let item = NSMenuItem(
                title: seconds == 1 ? "1 second" : "\(seconds) seconds",
                action: #selector(selectInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = option
            intervalItems.append(item)
            intervalMenu.addItem(item)
        }
        intervalParent.submenu = intervalMenu
        menu.addItem(intervalParent)

        let launch = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launch.target = self
        launchItem = launch
        menu.addItem(launch)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About OnTop", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit OnTop", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        refreshChecks()
    }

    private func updateMenuValues() {
        for reader in readers {
            guard let item = rowItems[reader.id], let reading = latest[reader.id] else { continue }
            item.attributedTitle = menuTitle(name: reader.name, value: reading.menuValue)
        }
    }

    /// Two-column row: label on the left, value aligned at a tab stop.
    private func menuTitle(name: String, value: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: 92)]
        let title = NSMutableAttributedString(
            string: name + "\t",
            attributes: [
                .font: NSFont.menuFont(ofSize: 13),
                .paragraphStyle: paragraph,
            ]
        )
        title.append(NSAttributedString(
            string: value,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph,
            ]
        ))
        return title
    }

    private func refreshChecks() {
        for reader in readers {
            rowItems[reader.id]?.state = (reader.id == primaryID) ? .on : .off
        }
        for item in intervalItems {
            let option = item.representedObject as? TimeInterval ?? -1
            item.state = (abs(option - interval) < 0.01) ? .on : .off
        }
        launchItem?.state = launchAtLoginEnabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func selectPrimary(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        primaryID = id
        defaults.set(id, forKey: "primaryID")
        refreshChecks()
        updateBar()
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let option = sender.representedObject as? TimeInterval else { return }
        interval = option
        defaults.set(option, forKey: "interval")
        refreshChecks()
        startTimer()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("OnTop: launch-at-login change failed: \(error.localizedDescription)")
        }
        sender.state = launchAtLoginEnabled ? .on : .off
    }

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let alert = NSAlert()
        alert.messageText = "OnTop \(version)"
        alert.informativeText = """
            A lightweight, open-source system monitor for the menu bar.

            Click any stat in the dropdown to promote it to the menu-bar slot.
            MIT licensed.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuValues()
    }
}

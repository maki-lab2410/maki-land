import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard: if another copy is already running (e.g. started by login item + LaunchAgent), quit this one silently
        if let bundleID = Bundle.main.bundleIdentifier {
            let me = ProcessInfo.processInfo.processIdentifier
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != me && !$0.isTerminated }
            if let older = others.min(by: { ($0.launchDate ?? .distantFuture) < ($1.launchDate ?? .distantFuture) }),
               (older.launchDate ?? .distantFuture) <= (NSRunningApplication.current.launchDate ?? .distantFuture) {
                NSApp.terminate(nil)
                return
            }
        }

        // Prevent app from showing Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Setup standard Edit menu so responder chain shortcuts (Cmd+A/C/V/X/Z) work natively
        setupMainMenu()

        // Start 24/7 real-time clipboard monitoring immediately at launch (CopyClip style)
        ClipboardService.shared.startMonitoring()

        // Setup Island panel & restore Coucou-style Desktop Maki if enabled
        IslandController.shared.setup()
        DesktopCapyController.shared.restoreIfNeeded()

        // Initialize Launch at Login (Boot/Nyala) and Lock Screen observers
        AutoLaunchService.shared.setLaunchAtLogin(enabled: AutoLaunchService.shared.isLaunchAtLoginEnabled)
        LockScreenService.shared.startObserving()

        // Setup Menu Bar Extra
        setupStatusItem()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Keluar maki-land", action: #selector(quitApp), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Standard Edit Menu for NSTextView / NSTextField
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "capsule", accessibilityDescription: "maki-land")
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Tampilkan/Sembunyikan Island",
            action: #selector(toggleVisibility),
            keyEquivalent: "i"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let expandItem = NSMenuItem(
            title: "Buka/Tutup Mode Detail",
            action: #selector(toggleExpanded),
            keyEquivalent: "e"
        )
        expandItem.target = self
        menu.addItem(expandItem)

        let desktopCapyItem = NSMenuItem(
            title: "🐾 Lepas/Panggil Maki di Desktop",
            action: #selector(toggleDesktopCapy),
            keyEquivalent: "m"
        )
        desktopCapyItem.target = self
        menu.addItem(desktopCapyItem)

        menu.addItem(NSMenuItem.separator())

        // Quick Tab Switcher Submenu
        let tabMenu = NSMenu()
        let entries: [(String, IslandTab, String)] = [
            ("✨ maki-land (Musik & Kalender)", .makiLand, "1"),
            ("🐾 Capybara (Maki)", .capy, "2"),
            ("📝 Notes & To-Do", .notes, "3"),
            ("🚀 Quick Launch", .launcher, "4"),
            ("📁 Tray & PDF Studio", .tray, "5"),
            ("📊 System Monitor", .monitor, "6"),
            ("📋 Clipboard History", .clipboard, "7"),
            ("⏳ Timer", .timer, "8")
        ]
        for ( idx, entry ) in entries.enumerated() {
            let item = NSMenuItem(title: entry.0, action: #selector(selectTabFromMenu(_:)), keyEquivalent: entry.2)
            item.tag = idx
            item.target = self
            tabMenu.addItem(item)
        }

        let tabsMenuItem = NSMenuItem(title: "Pilih Widget", action: nil, keyEquivalent: "")
        tabsMenuItem.submenu = tabMenu
        menu.addItem(tabsMenuItem)

        menu.addItem(NSMenuItem.separator())

        let autoLaunchItem = NSMenuItem(
            title: "⚡ Buka Otomatis saat Booting / Nyala",
            action: #selector(toggleAutoLaunch),
            keyEquivalent: ""
        )
        autoLaunchItem.state = AutoLaunchService.shared.isLaunchAtLoginEnabled ? .on : .off
        autoLaunchItem.target = self
        menu.addItem(autoLaunchItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Keluar maki-land",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleVisibility() {
        IslandController.shared.toggleVisibility()
    }

    @objc private func toggleExpanded() {
        IslandState.shared.toggleExpand()
    }

    @objc private func toggleDesktopCapy() {
        CapybaraService.shared.toggleDesktopMode()
    }

    @objc private func toggleAutoLaunch(_ sender: NSMenuItem) {
        AutoLaunchService.shared.toggle()
        sender.state = AutoLaunchService.shared.isLaunchAtLoginEnabled ? .on : .off
    }

    @objc private func selectTabFromMenu(_ sender: NSMenuItem) {
        let allTabs = IslandTab.allCases
        if sender.tag >= 0 && sender.tag < allTabs.count {
            IslandState.shared.selectedTab = allTabs[sender.tag]
            IslandState.shared.setExpanded(true)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

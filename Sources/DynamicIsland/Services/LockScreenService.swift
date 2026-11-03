import Foundation
import AppKit

public class LockScreenService {
    public static let shared = LockScreenService()

    private var isCurrentlyLocked: Bool = false

    private init() {}

    public func startObserving() {
        let dist = DistributedNotificationCenter.default()

        // macOS LoginWindow lock & unlock notifications
        dist.addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        dist.addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        // Workspace screen sleep & wake notifications
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        ws.addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func handleScreenLocked() {
        guard !isCurrentlyLocked else { return }
        isCurrentlyLocked = true
        DispatchQueue.main.async {
            DesktopCapyController.shared.stopCurrentWalk()
            CapybaraService.shared.triggerSpecificActivity(.sleeping, message: "tidur dulu ya zZz.. 🌙", duration: 999999)
            DesktopCapyController.shared.panel?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
            IslandController.shared.panel?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        }
    }

    @objc private func handleScreenUnlocked() {
        guard isCurrentlyLocked else { return }
        isCurrentlyLocked = false
        DispatchQueue.main.async {
            CapybaraService.shared.wakeUpFromSleep()
            DesktopCapyController.shared.panel?.level = .statusBar
            IslandController.shared.panel?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        }
    }
}

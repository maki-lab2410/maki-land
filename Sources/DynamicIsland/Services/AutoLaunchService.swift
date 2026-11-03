import Foundation
import ServiceManagement
import AppKit

public class AutoLaunchService: ObservableObject {
    public static let shared = AutoLaunchService()

    private let storageKey = "maki_launch_at_login"
    private let agentPlistName = "com.local.makiland.plist"

    @Published public var isLaunchAtLoginEnabled: Bool = true

    private var launchAgentURL: URL {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let agentsURL = libraryURL.appendingPathComponent("LaunchAgents", isDirectory: true)
        return agentsURL.appendingPathComponent(agentPlistName)
    }

    private init() {
        let d = UserDefaults.standard
        if d.object(forKey: storageKey) == nil {
            // First time: enable by default as requested by the user
            setLaunchAtLogin(enabled: true)
        } else {
            isLaunchAtLoginEnabled = d.bool(forKey: storageKey)
            if isLaunchAtLoginEnabled && !FileManager.default.fileExists(atPath: launchAgentURL.path) {
                installLaunchAgent()
            }
        }
    }

    public func toggle() {
        setLaunchAtLogin(enabled: !isLaunchAtLoginEnabled)
    }

    public func setLaunchAtLogin(enabled: Bool) {
        isLaunchAtLoginEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: storageKey)

        // Use ONE autostart mechanism only (LaunchAgent). Registering SMAppService as well launches a second copy at login!
        if #available(macOS 13.0, *), SMAppService.mainApp.status != .notRegistered {
            try? SMAppService.mainApp.unregister()
        }

        if enabled {
            installLaunchAgent()
        } else {
            removeLaunchAgent()
        }
    }

    private func installLaunchAgent() {
        let fm = FileManager.default
        let folder = launchAgentURL.deletingLastPathComponent()
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let appPath = Bundle.main.executablePath ?? "/Applications/makiland.app/Contents/MacOS/makiland"
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>Label</key>
        \t<string>com.local.makiland</string>
        \t<key>ProgramArguments</key>
        \t<array>
        \t\t<string>\(appPath)</string>
        \t</array>
        \t<key>RunAtLoad</key>
        \t<true/>
        \t<key>ProcessType</key>
        \t<string>Interactive</string>
        \t<key>LimitLoadToSessionType</key>
        \t<string>Aqua</string>
        </dict>
        </plist>
        """

        try? plistContent.write(to: launchAgentURL, atomically: true, encoding: .utf8)
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(at: launchAgentURL)
    }
}

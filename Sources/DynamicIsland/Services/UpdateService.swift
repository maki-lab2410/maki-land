import Foundation
import AppKit
import Combine

public final class UpdateService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = UpdateService()

    public var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    public let repoOwner = "maki-lab2410"
    public let repoName = "maki-land"

    @Published public var isUpdateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var releaseTitle: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var releasePageURL: URL? = nil
    @Published public var downloadURL: URL? = nil
    @Published public var zipDownloadURL: URL? = nil
    @Published public var isChecking: Bool = false
    @Published public var lastCheckTime: Date? = nil
    @Published public var statusMessage: String = ""

    // 1-Click In-App In-Place Auto Updater States
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadBytesString: String = ""
    @Published public var isInstallingUpdate: Bool = false
    @Published public var installStatusText: String = ""
    @Published public var updateError: String? = nil

    private var pollTimer: Timer?
    private var activeDownloadTask: URLSessionDownloadTask?

    public override init() {
        super.init()
        // Run background check shortly after startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
            self?.checkForUpdates(manual: false)
        }
        // Poll every 4 hours
        pollTimer = Timer.scheduledTimer(withTimeInterval: 14400, repeats: true) { [weak self] _ in
            self?.checkForUpdates(manual: false)
        }
    }

    public func checkForUpdates(manual: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        if manual {
            statusMessage = "Memeriksa pembaruan di GitHub..."
        }

        let apiURLString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: apiURLString) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("makiland-app", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false
                self.lastCheckTime = Date()

                if let error = error {
                    if manual {
                        self.statusMessage = "Gagal terhubung ke GitHub: \(error.localizedDescription)"
                    }
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    if manual {
                        self.statusMessage = "Belum ada rilis baru yang dipublikasikan."
                    }
                    return
                }

                let rawTag = (json["tag_name"] as? String) ?? ""
                let cleanTag = rawTag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let title = (json["name"] as? String) ?? rawTag
                let body = (json["body"] as? String) ?? ""
                let htmlURLStr = (json["html_url"] as? String) ?? "https://github.com/\(self.repoOwner)/\(self.repoName)/releases"
                let htmlURL = URL(string: htmlURLStr)

                var directZipURL: URL? = nil
                var directDmgURL: URL? = nil

                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           let dlStr = asset["browser_download_url"] as? String,
                           let dl = URL(string: dlStr) {
                            let lower = name.lowercased()
                            if lower.hasSuffix(".zip") && (lower.contains("mac") || lower.contains("maki")) {
                                directZipURL = dl
                            } else if lower.hasSuffix(".dmg") && (lower.contains("mac") || lower.contains("maki")) {
                                directDmgURL = dl
                            }
                        }
                    }
                }

                let chosenAsset = directZipURL ?? directDmgURL

                if !cleanTag.isEmpty && self.isVersion(cleanTag, higherThan: self.currentVersion) {
                    self.isUpdateAvailable = true
                    self.latestVersion = cleanTag
                    self.releaseTitle = title
                    self.releaseNotes = body
                    self.releasePageURL = htmlURL
                    self.zipDownloadURL = chosenAsset
                    self.downloadURL = chosenAsset ?? htmlURL
                    self.statusMessage = "Versi baru v\(cleanTag) tersedia!"
                    CapybaraService.shared.showDesktopBubble("Ada pembaruan baru maki-land v\(cleanTag) lho! ✨", duration: 5.0)
                } else {
                    self.isUpdateAvailable = false
                    if manual {
                        self.statusMessage = "Aplikasi sudah menggunakan versi terbaru (v\(self.currentVersion)) ✨"
                    }
                }
            }
        }.resume()
    }

    /// 1-Click Automatic In-App In-Place Update:
    /// Downloads the archive, replaces the running application bundle, and relaunches seamlessly!
    public func start1ClickAutoUpdate() {
        guard let targetURL = zipDownloadURL ?? downloadURL else {
            openReleaseOrDownload()
            return
        }

        // If the URL is not a downloadable archive, fallback to opening browser
        let ext = targetURL.pathExtension.lowercased()
        if ext != "zip" && ext != "dmg" {
            openReleaseOrDownload()
            return
        }

        updateError = nil
        isDownloading = true
        isInstallingUpdate = false
        downloadProgress = 0.0
        downloadBytesString = "0 MB"
        installStatusText = "Mempersiapkan pengunduhan..."

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.downloadTask(with: targetURL)
        self.activeDownloadTask = task
        task.resume()
    }

    public func cancelUpdate() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        isDownloading = false
        isInstallingUpdate = false
        downloadProgress = 0.0
        installStatusText = ""
    }

    public func openReleaseOrDownload() {
        if let target = downloadURL ?? releasePageURL {
            NSWorkspace.shared.open(target)
        } else if let fallback = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
            NSWorkspace.shared.open(fallback)
        }
    }

    // MARK: - URLSessionDownloadDelegate
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.downloadProgress = min(1.0, max(0.0, progress))
            let writtenMB = Double(totalBytesWritten) / (1024 * 1024)
            let totalMB = Double(totalBytesExpectedToWrite) / (1024 * 1024)
            self.downloadBytesString = String(format: "%.1f MB / %.1f MB (%.0f%%)", writtenMB, totalMB, progress * 100)
            self.installStatusText = "Mengunduh pembaruan: \(self.downloadBytesString)"
        } else {
            let writtenMB = Double(totalBytesWritten) / (1024 * 1024)
            self.downloadBytesString = String(format: "%.1f MB", writtenMB)
            self.installStatusText = "Mengunduh pembaruan: \(self.downloadBytesString)"
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let isDMG = downloadTask.originalRequest?.url?.pathExtension.lowercased() == "dmg"
        let tempFile = URL(fileURLWithPath: "/tmp/makiland_update_\(UUID().uuidString).\(isDMG ? "dmg" : "zip")")
        try? FileManager.default.removeItem(at: tempFile)
        do {
            try FileManager.default.moveItem(at: location, to: tempFile)
            applyMacUpdate(fromArchive: tempFile)
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.updateError = "Gagal memproses file unduhan: \(error.localizedDescription)"
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.isInstallingUpdate = false
                self.updateError = "Unduhan terputus: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - In-Place Application Bundle Replacement & Relaunch
    private func applyMacUpdate(fromArchive archiveURL: URL) {
        DispatchQueue.main.async {
            self.isDownloading = false
            self.isInstallingUpdate = true
            self.installStatusText = "Mengekstrak paket pembaruan..."
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let stagingDir = URL(fileURLWithPath: "/tmp/makiland_staging_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

            var extractedAppPath: String? = nil

            if archiveURL.pathExtension.lowercased() == "dmg" {
                let mountPoint = "/tmp/makiland_mount_\(UUID().uuidString)"
                let attachProc = Process()
                attachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                attachProc.arguments = ["attach", archiveURL.path, "-mountpoint", mountPoint, "-nobrowse", "-quiet"]
                try? attachProc.run()
                attachProc.waitUntilExit()

                if let appURL = self.findAppBundle(in: URL(fileURLWithPath: mountPoint)) {
                    let targetStagingApp = stagingDir.appendingPathComponent(appURL.lastPathComponent)
                    try? FileManager.default.copyItem(at: appURL, to: targetStagingApp)
                    extractedAppPath = targetStagingApp.path
                }

                let detachProc = Process()
                detachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProc.arguments = ["detach", mountPoint, "-force", "-quiet"]
                try? detachProc.run()
                detachProc.waitUntilExit()
            } else {
                let unzipProc = Process()
                unzipProc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProc.arguments = ["-q", "-o", archiveURL.path, "-d", stagingDir.path]
                try? unzipProc.run()
                unzipProc.waitUntilExit()

                if let appURL = self.findAppBundle(in: stagingDir) {
                    extractedAppPath = appURL.path
                }
            }

            guard let newAppPath = extractedAppPath else {
                DispatchQueue.main.async {
                    self.isInstallingUpdate = false
                    self.updateError = "File aplikasi tidak ditemukan di dalam paket rilis."
                }
                return
            }

            let currentAppURL = Bundle.main.bundleURL
            let currentPID = ProcessInfo.processInfo.processIdentifier

            DispatchQueue.main.async {
                self.installStatusText = "Memasang versi terbaru & memulai ulang..."
            }

            let scriptPath = "/tmp/makiland_apply_update.sh"
            let scriptContent = """
            #!/bin/bash
            TARGET_PID=\(currentPID)
            NEW_APP="\(newAppPath)"
            DEST_APP="\(currentAppURL.path)"

            # Wait up to 6 seconds for current process to cleanly exit
            for i in {1..60}; do
                if ! kill -0 "$TARGET_PID" 2>/dev/null; then
                    break
                fi
                sleep 0.1
            done

            # Replace the old application bundle directly in /Applications
            rm -rf "$DEST_APP"
            cp -R "$NEW_APP" "$DEST_APP"

            # Remove Gatekeeper quarantine so the update launches without security prompts
            xattr -cr "$DEST_APP" 2>/dev/null || true

            # Clean temporary files
            rm -rf "\(stagingDir.path)"
            rm -f "\(archiveURL.path)"
            rm -f "\(scriptPath)"

            # Relaunch the new application
            open "$DEST_APP"
            """

            try? scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            let chmodProc = Process()
            chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProc.arguments = ["+x", scriptPath]
            try? chmodProc.run()
            chmodProc.waitUntilExit()

            // Spawn updater script in background detached
            let spawnProc = Process()
            spawnProc.executableURL = URL(fileURLWithPath: "/bin/bash")
            spawnProc.arguments = [scriptPath]
            try? spawnProc.run()

            // Terminate current running app cleanly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSApp.terminate(nil)
            }
        }
    }

    private func findAppBundle(in dir: URL) -> URL? {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for item in contents {
                if item.pathExtension == "app" {
                    return item
                }
                if item.hasDirectoryPath {
                    if let nested = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                        for sub in nested where sub.pathExtension == "app" {
                            return sub
                        }
                    }
                }
            }
        }
        return nil
    }

    private func isVersion(_ v1: String, higherThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(parts1.count, parts2.count)

        for i in 0..<maxCount {
            let num1 = i < parts1.count ? parts1[i] : 0
            let num2 = i < parts2.count ? parts2[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }
}

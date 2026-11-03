import Foundation
import AppKit
import Combine

public final class UpdateService: ObservableObject {
    public static let shared = UpdateService()

    public let currentVersion: String = "1.0.0"
    public let repoOwner = "maki-lab2410"
    public let repoName = "maki-land"

    @Published public var isUpdateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var releaseTitle: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var releasePageURL: URL? = nil
    @Published public var downloadURL: URL? = nil
    @Published public var isChecking: Bool = false
    @Published public var lastCheckTime: Date? = nil
    @Published public var statusMessage: String = ""
    @Published public var isDownloading: Bool = false

    private var pollTimer: Timer?

    private init() {
        // Run background check shortly after startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
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
        request.setValue("maki-land-app", forHTTPHeaderField: "User-Agent")

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

                var directAssetURL: URL? = nil
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           let dlStr = asset["browser_download_url"] as? String,
                           let dl = URL(string: dlStr) {
                            if name.localizedCaseInsensitiveContains("mac") || name.hasSuffix(".zip") {
                                directAssetURL = dl
                                break
                            }
                        }
                    }
                }

                if !cleanTag.isEmpty && self.isVersion(cleanTag, higherThan: self.currentVersion) {
                    self.isUpdateAvailable = true
                    self.latestVersion = cleanTag
                    self.releaseTitle = title
                    self.releaseNotes = body
                    self.releasePageURL = htmlURL
                    self.downloadURL = directAssetURL ?? htmlURL
                    self.statusMessage = "Versi baru v\(cleanTag) tersedia!"
                    // Friendly speech bubble from Maki
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

    public func openReleaseOrDownload() {
        if let target = downloadURL ?? releasePageURL {
            NSWorkspace.shared.open(target)
        } else if let fallback = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
            NSWorkspace.shared.open(fallback)
        }
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

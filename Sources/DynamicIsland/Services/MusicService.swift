import Foundation
import AppKit

public struct TrackInfo: Equatable {
    public var title: String = ""
    public var artist: String = ""
    public var isPlaying: Bool = false
    public var appName: String = ""
    public var appBundleId: String = ""
    public var duration: Double = 0.0
    public var elapsed: Double = 0.0
    public var isFromBrowser: Bool = false

    public var displayAppName: String {
        if !appName.isEmpty { return appName }
        return "Musik"
    }
}

public class MusicService: ObservableObject {
    public static let shared = MusicService()

    @Published public var currentTrack = TrackInfo()
    @Published public var hasActiveMedia = false

    private var pollTimer: Timer?
    private let jsonPath = "/tmp/dynamic_island_media.json"
    private let cmdPath = "/tmp/dynamic_island_cmd"
    private var optimisticToggleUntil: Date = .distantPast
    private var optimisticIsPlaying: Bool? = nil

    private init() {
        ensureDaemonRunning()
        readMediaStatus()

        let timer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.readMediaStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    public func ensureDaemonRunning() {
        let lockPath = "/tmp/dynamic_island_helper.lock"
        let fd = open(lockPath, O_RDWR)
        if fd < 0 {
            startHelperDaemon()
        } else {
            if flock(fd, LOCK_EX | LOCK_NB) == 0 {
                flock(fd, LOCK_UN)
                close(fd)
                startHelperDaemon()
            } else {
                close(fd)
            }
        }
    }

    private func startHelperDaemon() {
        let script = Bundle.main.path(forResource: "media-helper", ofType: "swift")
            ?? "/Applications/makiland.app/Contents/Resources/media-helper.swift"

        if FileManager.default.fileExists(atPath: script) {
            spawnProcess("/usr/bin/swift", [script])
        }
    }

    public func checkCurrentTrack() {
        readMediaStatus()
    }

    public func readMediaStatus() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let title = json["title"] as? String ?? ""
        let artist = json["artist"] as? String ?? ""
        var isPlaying = json["isPlaying"] as? Bool ?? false
        let duration = json["duration"] as? Double ?? 0.0
        let elapsed = json["elapsed"] as? Double ?? 0.0
        let hasMedia = json["hasMedia"] as? Bool ?? false
        let appName = json["appName"] as? String ?? ""
        let bundleId = json["bundleId"] as? String ?? ""
        let isFromBrowser = json["isFromBrowser"] as? Bool ?? false

        DispatchQueue.main.async {
            let now = Date()
            if now < self.optimisticToggleUntil, let optPlay = self.optimisticIsPlaying {
                if isPlaying == optPlay {
                    // Confirmed by daemon
                    self.optimisticToggleUntil = .distantPast
                    self.optimisticIsPlaying = nil
                } else {
                    // Hold optimistic state during short IPC roundtrip to prevent wave flicker
                    isPlaying = optPlay
                }
            } else {
                self.optimisticIsPlaying = nil
            }

            if hasMedia && !title.isEmpty {
                let resolvedApp = appName.isEmpty ? (isFromBrowser ? "YouTube" : "Musik") : appName
                let nextTrack = TrackInfo(
                    title: title,
                    artist: artist,
                    isPlaying: isPlaying,
                    appName: resolvedApp,
                    appBundleId: bundleId,
                    duration: duration,
                    elapsed: round(elapsed),
                    isFromBrowser: isFromBrowser
                )
                if self.currentTrack != nextTrack {
                    self.currentTrack = nextTrack
                }
                if !self.hasActiveMedia {
                    self.hasActiveMedia = true
                }
            } else {
                if self.hasActiveMedia || !self.currentTrack.title.isEmpty || self.currentTrack.isPlaying {
                    self.currentTrack = TrackInfo()
                    self.hasActiveMedia = false
                }
            }
        }
    }

    public func togglePlayPause() {
        let nextState = !currentTrack.isPlaying
        optimisticIsPlaying = nextState
        optimisticToggleUntil = Date().addingTimeInterval(1.1)
        currentTrack.isPlaying = nextState
        sendCommand("toggle")
    }

    public func nextTrack() {
        optimisticIsPlaying = nil
        optimisticToggleUntil = .distantPast
        sendCommand("next")
    }

    public func previousTrack() {
        optimisticIsPlaying = nil
        optimisticToggleUntil = .distantPast
        sendCommand("prev")
    }

    private func sendCommand(_ action: String) {
        try? action.write(toFile: cmdPath, atomically: true, encoding: .utf8)
        ensureDaemonRunning()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.readMediaStatus()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            self?.readMediaStatus()
        }
    }

    private func spawnProcess(_ path: String, _ args: [String]) {
        var pid: pid_t = 0
        let allArgs = [path] + args
        var cArgs: [UnsafeMutablePointer<CChar>?] = allArgs.map { strdup($0) }
        cArgs.append(nil)
        defer {
            for ptr in cArgs {
                if let p = ptr { free(p) }
            }
        }
        _ = posix_spawn(&pid, path, nil, nil, cArgs, nil)
    }
}

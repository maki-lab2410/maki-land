import Foundation
import AppKit

// Prevent duplicate helper daemon instances using file lock
let lockPath = "/tmp/dynamic_island_helper.lock"
let lockFd = open(lockPath, O_CREAT | O_RDWR, 0o666)
if lockFd < 0 || flock(lockFd, LOCK_EX | LOCK_NB) != 0 {
    exit(0)
}

let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
guard let h = handle else { exit(1) }

typealias RegFn = @convention(c) (DispatchQueue) -> Void
if let regSym = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications") {
    let reg = unsafeBitCast(regSym, to: RegFn.self)
    reg(DispatchQueue.main)
}

typealias SendCmdFn = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
let sendCmd: SendCmdFn? = {
    guard let s = dlsym(h, "MRMediaRemoteSendCommand") else { return nil }
    return unsafeBitCast(s, to: SendCmdFn.self)
}()

typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
guard let infoSym = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") else { exit(1) }
let getInfo = unsafeBitCast(infoSym, to: GetInfoFn.self)

typealias IsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
let isPlayingFn: IsPlayingFn? = {
    guard let s = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else { return nil }
    return unsafeBitCast(s, to: IsPlayingFn.self)
}()

typealias GetPIDFn = @convention(c) (DispatchQueue, @escaping (pid_t) -> Void) -> Void
let getPIDFn: GetPIDFn? = {
    guard let s = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationPID") else { return nil }
    return unsafeBitCast(s, to: GetPIDFn.self)
}()

let jsonPath = "/tmp/dynamic_island_media.json"
let cmdPath = "/tmp/dynamic_island_cmd"

func executeCommand(_ action: String) {
    let act = action.trimmingCharacters(in: .whitespacesAndNewlines)
    switch act {
    case "toggle":
        _ = sendCmd?(2, nil)
    case "play":
        _ = sendCmd?(0, nil)
    case "pause":
        _ = sendCmd?(1, nil)
    case "next":
        _ = sendCmd?(4, nil)
    case "prev":
        _ = sendCmd?(5, nil)
    default:
        break
    }
}

func writeMediaJSON(_ out: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: out, options: []) {
        try? data.write(to: URL(fileURLWithPath: jsonPath), options: .atomic)
    }
}

func fetchAndSave() {
    let handlePlayingResult: (Bool?) -> Void = { playingOpt in
        getPIDFn?(DispatchQueue.main) { pid in
            var appName = ""
            var bundleId = ""
            var isBrowser = false

            if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                appName = app.localizedName ?? ""
                bundleId = app.bundleIdentifier ?? ""
            }

            let browserBundleIds: Set<String> = [
                "com.google.Chrome",
                "com.google.Chrome.canary",
                "com.apple.Safari",
                "org.mozilla.firefox",
                "company.thebrowser.Browser",
                "com.microsoft.edgemac",
                "com.brave.Browser",
                "com.operasoftware.Opera"
            ]

            let browserNames: Set<String> = [
                "Chrome", "Google Chrome", "Safari", "Arc", "Firefox", "Microsoft Edge", "Brave Browser", "Opera"
            ]

            if browserBundleIds.contains(bundleId) || browserNames.contains(appName) {
                isBrowser = true
            }

            var resolvedAppName = appName
            if appName.caseInsensitiveCompare("Spotify") == .orderedSame || bundleId == "com.spotify.client" {
                resolvedAppName = "Spotify"
                isBrowser = false
            } else if appName.caseInsensitiveCompare("Music") == .orderedSame || bundleId == "com.apple.Music" {
                resolvedAppName = "Apple Music"
                isBrowser = false
            } else if isBrowser {
                resolvedAppName = "YouTube"
            }

            getInfo(DispatchQueue.main) { info in
                let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
                var artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
                let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
                let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double

                let isPlaying: Bool
                if let playing = playingOpt {
                    isPlaying = playing
                } else {
                    isPlaying = (rate ?? 0.0) > 0.01
                }

                var cleanTitle = title
                if artist.isEmpty && title.contains(" - ") {
                    let parts = title.components(separatedBy: " - ")
                    if parts.count >= 2 {
                        artist = parts[0].trimmingCharacters(in: .whitespaces)
                        cleanTitle = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                    }
                }
                if artist.hasSuffix("VEVO") {
                    artist = String(artist.dropLast(4)).trimmingCharacters(in: .whitespaces)
                }

                let out: [String: Any] = [
                    "title": cleanTitle,
                    "artist": artist,
                    "isPlaying": isPlaying && !cleanTitle.isEmpty,
                    "appName": resolvedAppName,
                    "bundleId": bundleId,
                    "isFromBrowser": isBrowser,
                    "duration": duration,
                    "elapsed": elapsed,
                    "hasMedia": !cleanTitle.isEmpty,
                    "updatedAt": Date().timeIntervalSince1970
                ]

                writeMediaJSON(out)
            }
        }
    }

    if let fn = isPlayingFn {
        fn(DispatchQueue.main) { playing in
            handlePlayingResult(playing)
        }
    } else {
        handlePlayingResult(nil)
    }
}

// Instant push notifications from MediaRemote
let notificationNames = [
    "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
    "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
]
for name in notificationNames {
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name(name),
        object: nil,
        queue: .main
    ) { _ in
        fetchAndSave()
    }
}

// Fast IPC: Poll for incoming command every 80ms
let cmdTimer = Timer(timeInterval: 0.08, repeats: true) { _ in
    if FileManager.default.fileExists(atPath: cmdPath) {
        if let cmd = try? String(contentsOfFile: cmdPath, encoding: .utf8) {
            try? FileManager.default.removeItem(atPath: cmdPath)
            executeCommand(cmd)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                fetchAndSave()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                fetchAndSave()
            }
        }
    }
}
RunLoop.main.add(cmdTimer, forMode: .common)

// Fallback refresh metadata every 1s
let infoTimer = Timer(timeInterval: 1.0, repeats: true) { _ in
    fetchAndSave()
}
RunLoop.main.add(infoTimer, forMode: .common)

// Initial fetch
fetchAndSave()

RunLoop.main.run()

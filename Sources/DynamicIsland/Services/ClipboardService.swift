import Foundation
import AppKit

public enum ClipboardContentKind: String, Codable, Equatable {
    case text
    case url
    case file
    case image
}

public struct ClipboardItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var kind: ClipboardContentKind
    public var text: String
    public var secondaryPath: String? // File path or cached image path
    public var date: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        kind: ClipboardContentKind,
        text: String,
        secondaryPath: String? = nil,
        date: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.secondaryPath = secondaryPath
        self.date = date
        self.isPinned = isPinned
    }

    public var preview: String {
        let singleLine = text
            .replacingOccurrences(of: "\r\n", with: " ↵ ")
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if singleLine.count > 90 {
            return String(singleLine.prefix(90)) + "…"
        }
        return singleLine
    }

    public var relativeTime: String {
        let sec = Int(Date().timeIntervalSince(date))
        if sec < 5 { return "baru saja" }
        if sec < 60 { return "\(sec)d" }
        let min = sec / 60
        if min < 60 { return "\(min)m" }
        let hr = min / 60
        if hr < 24 { return "\(hr)j" }
        return "\(hr / 24)h"
    }
}

public class ClipboardService: ObservableObject {
    public static let shared = ClipboardService()

    @Published public var history: [ClipboardItem] = [] {
        didSet { saveHistory() }
    }
    @Published public var currentText: String = ""
    @Published public var lastCapturedTrigger: Int = 0

    private var timer: Timer?
    private var lastChangeCount: Int = -1
    private var isInternalCopy: Bool = false

    private let maxHistory = 40
    private let storageKey = "maki_clipboard_history_v2"
    private let imageCacheDir: URL = {
        let dir = URL(fileURLWithPath: "/tmp/maki_clipboard_imgs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        loadHistory()
        // Force initial capture of whatever is currently on macOS clipboard
        lastChangeCount = NSPasteboard.general.changeCount - 1
        checkClipboard(isInitialBoot: true)

        // CopyClip-grade fast 200ms polling on .common RunLoop mode (never pauses during scroll/menus)
        let poll = Timer(timeInterval: 0.20, repeats: true) { [weak self] _ in
            self?.checkClipboard(isInitialBoot: false)
        }
        RunLoop.main.add(poll, forMode: .common)
        timer = poll
    }

    public func startMonitoring() {
        // Accessing .shared triggers init(); explicit no-op helper for AppDelegate clarity
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return
        }
        // Filter out image items whose temp cache vanished after reboot
        history = saved.filter { item in
            if item.kind == .image, let p = item.secondaryPath {
                return FileManager.default.fileExists(atPath: p)
            }
            return true
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func checkClipboard(isInitialBoot: Bool) {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if isInternalCopy {
            isInternalCopy = false
            return
        }

        // 1. Check for Copied Finder File URLs first (if no plain text or if file copy)
        if let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let firstFile = fileURLs.first {
            let label = fileURLs.count == 1
                ? firstFile.lastPathComponent
                : "\(firstFile.lastPathComponent) (+\(fileURLs.count - 1) file)"
            insertCapturedItem(
                ClipboardItem(kind: .file, text: label, secondaryPath: firstFile.path),
                notifyMascot: !isInitialBoot
            )
            return
        }

        // 2. Check for Text / URL / Code
        if let rawText = pb.string(forType: .string) {
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                currentText = rawText
                let isWebURL: Bool = {
                    guard !trimmed.contains(" "), let u = URL(string: trimmed),
                          let scheme = u.scheme?.lowercased() else { return false }
                    return scheme == "http" || scheme == "https"
                }()
                insertCapturedItem(
                    ClipboardItem(kind: isWebURL ? .url : .text, text: rawText),
                    notifyMascot: !isInitialBoot
                )
                return
            }
        }

        // 3. Check for Screenshot / Copied Image (.png or .tiff)
        if let imgData = pb.data(forType: .png) ?? pb.data(forType: .tiff),
           let nsImg = NSImage(data: imgData),
           let cg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            if let pngData = rep.representation(using: .png, properties: [:]) {
                let id = UUID()
                let imgURL = imageCacheDir.appendingPathComponent("\(id.uuidString).png")
                if (try? pngData.write(to: imgURL, options: .atomic)) != nil {
                    let dim = "\(cg.width)×\(cg.height)"
                    insertCapturedItem(
                        ClipboardItem(id: id, kind: .image, text: "Gambar (\(dim))", secondaryPath: imgURL.path),
                        notifyMascot: !isInitialBoot
                    )
                }
            }
        }
    }

    private func insertCapturedItem(_ newItem: ClipboardItem, notifyMascot: Bool) {
        var updated = history

        // Deduplicate & move existing identical clip to top (preserving pin state)
        var preservedPin = false
        if let existingIdx = updated.firstIndex(where: { existing in
            if existing.kind != newItem.kind { return false }
            if existing.kind == .text || existing.kind == .url {
                return existing.text == newItem.text
            }
            if existing.kind == .file {
                return existing.secondaryPath == newItem.secondaryPath
            }
            return false
        }) {
            preservedPin = updated[existingIdx].isPinned
            updated.remove(at: existingIdx)
        }

        var itemToInsert = newItem
        itemToInsert.isPinned = preservedPin

        // Insert right below pinned items (unless itself pinned)
        if itemToInsert.isPinned {
            updated.insert(itemToInsert, at: 0)
        } else {
            let firstUnpinnedIdx = updated.firstIndex(where: { !$0.isPinned }) ?? updated.count
            updated.insert(itemToInsert, at: firstUnpinnedIdx)
        }

        // Trim unpinned overflow beyond maxHistory
        if updated.count > maxHistory {
            updated = Array(updated.prefix(maxHistory))
        }

        history = updated
        if notifyMascot {
            lastCapturedTrigger += 1
            CapybaraService.shared.reactToEvent("udah kesalin ya")
        }
    }

    public func copyItem(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        isInternalCopy = true
        pb.clearContents()

        switch item.kind {
        case .text, .url:
            pb.setString(item.text, forType: .string)
            currentText = item.text
        case .file:
            if let path = item.secondaryPath {
                let fileURL = URL(fileURLWithPath: path)
                pb.writeObjects([fileURL as NSURL])
            } else {
                pb.setString(item.text, forType: .string)
            }
        case .image:
            if let path = item.secondaryPath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                pb.setData(data, forType: .png)
            }
        }

        lastChangeCount = pb.changeCount
        NSSound(named: "Tink")?.play()
    }

    /// Copies item and immediately returns focus to the previous active app (sending Cmd+V if trusted)
    public func copyAndPasteToActiveApp(_ item: ClipboardItem) {
        copyItem(item)
        IslandState.shared.setExpanded(false)
        NSApp.hide(nil)

        if AXIsProcessTrusted() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                let src = CGEventSource(stateID: .hidSystemState)
                let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // 'v'
                down?.flags = .maskCommand
                let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
                up?.flags = .maskCommand
                down?.post(tap: .cghidEventTap)
                up?.post(tap: .cghidEventTap)
            }
        }
    }

    public func togglePin(_ item: ClipboardItem) {
        guard let idx = history.firstIndex(where: { $0.id == item.id }) else { return }
        var copy = history
        copy[idx].isPinned.toggle()
        // Re-sort so pinned items stay on top
        let pinned = copy.filter { $0.isPinned }
        let unpinned = copy.filter { !$0.isPinned }
        history = pinned + unpinned
    }

    public func remove(_ item: ClipboardItem) {
        if item.kind == .image, let p = item.secondaryPath {
            try? FileManager.default.removeItem(atPath: p)
        }
        history.removeAll { $0.id == item.id }
    }

    public func clearAll() {
        // Keep pinned items, delete unpinned
        for item in history where !item.isPinned && item.kind == .image {
            if let p = item.secondaryPath {
                try? FileManager.default.removeItem(atPath: p)
            }
        }
        history.removeAll { !$0.isPinned }
    }
}

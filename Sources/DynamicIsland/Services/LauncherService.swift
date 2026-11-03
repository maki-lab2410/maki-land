import Foundation
import AppKit
import UniformTypeIdentifiers

public struct LauncherItem: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var name: String
    public var urlOrPath: String
    public var icon: String
    public var isWeb: Bool

    public init(id: UUID = UUID(), name: String, urlOrPath: String, icon: String, isWeb: Bool) {
        self.id = id
        self.name = name
        self.urlOrPath = urlOrPath
        self.icon = icon
        self.isWeb = isWeb
    }
}

public class LauncherService: ObservableObject {
    public static let shared = LauncherService()

    @Published public var items: [LauncherItem] = [] {
        didSet { saveItems() }
    }

    private let storageKey = "dynamic_island_launcher_items"

    private init() {
        loadItems()
    }

    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let list = try? JSONDecoder().decode([LauncherItem].self, from: data), !list.isEmpty {
            items = list
        } else {
            resetToDefaults()
        }
    }

    public func resetToDefaults() {
        items = [
            LauncherItem(name: "Finder", urlOrPath: "/System/Library/CoreServices/Finder.app", icon: "folder.fill", isWeb: false),
            LauncherItem(name: "Safari", urlOrPath: "/Applications/Safari.app", icon: "safari", isWeb: false),
            LauncherItem(name: "Terminal", urlOrPath: "/System/Applications/Utilities/Terminal.app", icon: "terminal.fill", isWeb: false),
            LauncherItem(name: "Downloads", urlOrPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path, icon: "arrow.down.circle.fill", isWeb: false),
            LauncherItem(name: "ChatGPT", urlOrPath: "https://chatgpt.com", icon: "sparkles", isWeb: true),
            LauncherItem(name: "GitHub", urlOrPath: "https://github.com", icon: "chevron.left.forwardslash.chevron.right", isWeb: true),
            LauncherItem(name: "YouTube", urlOrPath: "https://youtube.com", icon: "play.rectangle.fill", isWeb: true)
        ]
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    public func nativeIcon(for item: LauncherItem) -> NSImage? {
        guard !item.isWeb else { return nil }
        let path = (item.urlOrPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 64, height: 64)
        return img
    }

    public func launch(_ item: LauncherItem) {
        NSSound(named: "Pop")?.play()
        CapybaraService.shared.reactToEvent("buka \(item.name.lowercased()) ya")
        if item.isWeb {
            var raw = item.urlOrPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.contains("://") {
                raw = "https://" + raw
            }
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
            }
        } else {
            let path = (item.urlOrPath as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.open(url)
        }
    }

    public func revealInFinder(_ item: LauncherItem) {
        guard !item.isWeb else { return }
        let path = (item.urlOrPath as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Finder Application Picker

    public func pickApplicationsFromFinder(replacingId: UUID? = nil) {
        IslandState.shared.isModalOpen = true
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = replacingId == nil ? "Pilih Aplikasi atau Folder untuk Launch" : "Pilih Aplikasi Pengganti"
        panel.prompt = replacingId == nil ? "Tambahkan" : "Ganti"
        panel.message = "Pilih satu atau beberapa aplikasi (.app) atau folder dari Mac Anda"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = (replacingId == nil)
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [.application, .folder, .item]
        panel.level = .modalPanel

        panel.begin { [weak self] response in
            DispatchQueue.main.async {
                IslandState.shared.isModalOpen = false
                IslandController.shared.panel?.makeKeyAndOrderFront(nil)

                guard response == .OK, !panel.urls.isEmpty else { return }
                if let replaceId = replacingId, let firstURL = panel.urls.first {
                    self?.replaceWithFileURL(id: replaceId, url: firstURL)
                } else {
                    self?.addFromFileURLs(panel.urls)
                }
            }
        }
    }

    public func addFromFileURLs(_ urls: [URL]) {
        var addedAny = false
        for url in urls {
            let path = url.path
            if items.contains(where: { !$0.isWeb && $0.urlOrPath == path }) { continue }
            let cleanName = cleanDisplayName(for: url)
            items.append(LauncherItem(name: cleanName, urlOrPath: path, icon: "app.fill", isWeb: false))
            addedAny = true
        }
        if addedAny {
            NSSound(named: "Pop")?.play()
        }
    }

    public func replaceWithFileURL(id: UUID, url: URL) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx] = LauncherItem(
            id: id,
            name: cleanDisplayName(for: url),
            urlOrPath: url.path,
            icon: "app.fill",
            isWeb: false
        )
        NSSound(named: "Pop")?.play()
    }

    private func cleanDisplayName(for url: URL) -> String {
        var display = FileManager.default.displayName(atPath: url.path)
        if display.lowercased().hasSuffix(".app") {
            display = String(display.dropLast(4))
        }
        if display.isEmpty {
            display = url.deletingPathExtension().lastPathComponent
        }
        return display
    }

    public func addWebOrPath(name: String, urlOrPath: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = urlOrPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedTarget.isEmpty else { return }

        if trimmedTarget.hasPrefix("/") || trimmedTarget.hasPrefix("~/") {
            let expanded = (trimmedTarget as NSString).expandingTildeInPath
            items.append(LauncherItem(name: trimmedName, urlOrPath: expanded, icon: "app.fill", isWeb: false))
        } else {
            let normalizedURL = trimmedTarget.contains("://") ? trimmedTarget : "https://\(trimmedTarget)"
            let icon = smartWebIcon(for: normalizedURL, name: trimmedName)
            items.append(LauncherItem(name: trimmedName, urlOrPath: normalizedURL, icon: icon, isWeb: true))
        }
        NSSound(named: "Pop")?.play()
    }

    public func rename(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].name = trimmed
    }

    public func move(id: UUID, offset: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let target = idx + offset
        guard target >= 0 && target < items.count else { return }
        let item = items.remove(at: idx)
        items.insert(item, at: target)
    }

    public func delete(id: UUID) {
        items.removeAll { $0.id == id }
    }

    private func smartWebIcon(for url: String, name: String) -> String {
        let lower = (url + " " + name).lowercased()
        if lower.contains("github") || lower.contains("gitlab") { return "chevron.left.forwardslash.chevron.right" }
        if lower.contains("youtube") || lower.contains("netflix") { return "play.rectangle.fill" }
        if lower.contains("chatgpt") || lower.contains("claude") || lower.contains("gemini") { return "sparkles" }
        if lower.contains("figma") || lower.contains("canva") { return "paintbrush.pointed.fill" }
        if lower.contains("mail") || lower.contains("gmail") { return "envelope.fill" }
        if lower.contains("whatsapp") || lower.contains("discord") || lower.contains("telegram") { return "message.fill" }
        if lower.contains("docs") || lower.contains("notion") { return "doc.text.fill" }
        return "globe"
    }
}

import Foundation
import AppKit
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

public enum TrayFileKind: Equatable {
    case pdf(pageCount: Int)
    case image
    case other

    public var badgeText: String {
        switch self {
        case .pdf(let count): return "PDF • \(count) hal"
        case .image: return "GAMBAR"
        case .other: return "FILE"
        }
    }
}

public struct DroppedItem: Identifiable, Equatable {
    public let id: UUID
    public var url: URL
    public var name: String
    public var icon: NSImage
    public var sizeFormatted: String
    public var kind: TrayFileKind

    public init(id: UUID = UUID(), url: URL, name: String, icon: NSImage, sizeFormatted: String, kind: TrayFileKind) {
        self.id = id
        self.url = url
        self.name = name
        self.icon = icon
        self.sizeFormatted = sizeFormatted
        self.kind = kind
    }

    public static func == (lhs: DroppedItem, rhs: DroppedItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url && lhs.name == rhs.name && lhs.sizeFormatted == rhs.sizeFormatted && lhs.kind == rhs.kind
    }
}

public struct TrayStatusBanner: Equatable {
    public let message: String
    public let outputURL: URL?
    public let isError: Bool
}

public class DropZoneService: ObservableObject {
    public static let shared = DropZoneService()

    @Published public var droppedItems: [DroppedItem] = []
    @Published public var activeStudioItem: DroppedItem? = nil {
        didSet {
            IslandState.shared.notifySize()
        }
    }
    @Published public var isBusy: Bool = false
    @Published public var statusBanner: TrayStatusBanner? = nil

    private var bannerDismissWork: DispatchWorkItem?

    private init() {}

    public var mergeableItems: [DroppedItem] {
        droppedItems.filter {
            if case .pdf = $0.kind { return true }
            if case .image = $0.kind { return true }
            return false
        }
    }

    public static var supportedDraggedTypes: [NSPasteboard.PasteboardType] {
        var types = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        types.append(contentsOf: [
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            .png,
            .tiff,
            .pdf,
            NSPasteboard.PasteboardType(UTType.image.identifier),
            NSPasteboard.PasteboardType(UTType.data.identifier)
        ])
        return types
    }

    public static var supportedDropUTTypes: [UTType] {
        [.fileURL, .image, .png, .tiff, .jpeg, .pdf, .item]
    }

    public var screenshotStorageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport
            .appendingPathComponent("DynamicIsland", isDirectory: true)
            .appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func inspectURL(_ url: URL, existingId: UUID = UUID()) -> DroppedItem {
        let name = url.lastPathComponent

        var sizeStr = "Folder"
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                sizeStr = formatter.string(fromByteCount: size)
            }
        }

        let ext = url.pathExtension.lowercased()
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "tif", "bmp", "gif"]
        let kind: TrayFileKind
        if ext == "pdf", let doc = PDFDocument(url: url) {
            kind = .pdf(pageCount: doc.pageCount)
        } else if imageExts.contains(ext) {
            kind = .image
        } else {
            kind = .other
        }

        // For screenshots & images, render a light thumbnail via ImageIO (no full-size decode on the main thread = smooth drop animation!)
        let icon: NSImage
        if kind == .image, let thumb = Self.fastThumbnail(at: url, maxSide: 96) {
            icon = thumb
        } else {
            let sysIcon = NSWorkspace.shared.icon(forFile: url.path)
            sysIcon.size = NSSize(width: 64, height: 64)
            icon = sysIcon
        }

        return DroppedItem(id: existingId, url: url, name: name, icon: icon, sizeFormatted: sizeStr, kind: kind)
    }

    private static func fastThumbnail(at url: URL, maxSide: CGFloat) -> NSImage? {
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) else { return nil }
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide * 2
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
    }

    private static func makeThumbnail(from source: NSImage, maxSide: CGFloat) -> NSImage {
        let w = max(1, source.size.width)
        let h = max(1, source.size.height)
        let scale = min(1.0, maxSide / max(w, h))
        let targetSize = NSSize(width: max(16, round(w * scale)), height: max(16, round(h * scale)))
        let thumb = NSImage(size: targetSize)
        thumb.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        return thumb
    }

    @discardableResult
    public func addURLs(_ urls: [URL], selectFirstInStudio: Bool = false) -> DroppedItem? {
        var firstAdded: DroppedItem? = nil
        // Insert newest items at index 0 so screenshots given to Maki sit right at the front, ready to grab!
        for url in urls.reversed() {
            if let idx = droppedItems.firstIndex(where: { $0.url == url }) {
                let refreshed = inspectURL(url, existingId: droppedItems[idx].id)
                droppedItems.remove(at: idx)
                droppedItems.insert(refreshed, at: 0)
                firstAdded = refreshed
                continue
            }
            let item = inspectURL(url)
            droppedItems.insert(item, at: 0)
            firstAdded = item
        }
        if selectFirstInStudio, let target = firstAdded {
            activeStudioItem = target
        } else {
            // Ensure Tray opens on the Shelf view (not locked inside Studio) so the user can drag/copy immediately!
            activeStudioItem = nil
        }
        return firstAdded
    }

    // MARK: - Screenshot Saving, Drag Promise Extraction & Instant Copy

    public func saveImageAsScreenshot(_ image: NSImage, prefix: String = "Screenshot") -> URL? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return saveImageDataAsScreenshot(pngData, prefix: prefix, ext: "png")
    }

    public func saveImageDataAsScreenshot(_ data: Data, prefix: String = "Screenshot", ext: String = "png") -> URL? {
        // Normalize TIFF data (e.g. from macOS pasteboard/screencapture) into crisp PNG
        var finalData = data
        var finalExt = ext.lowercased()
        if finalExt != "png", let rep = NSBitmapImageRep(data: data),
           let png = rep.representation(using: .png, properties: [:]) {
            finalData = png
            finalExt = "png"
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = df.string(from: Date())
        let outURL = PDFStudioService.uniqueOutputURL(
            in: screenshotStorageDirectory,
            baseName: "\(prefix)_\(stamp)",
            ext: finalExt
        )
        do {
            try finalData.write(to: outURL, options: .atomic)
            return outURL
        } catch {
            return nil
        }
    }

    /// Extracts file URLs, promised macOS floating screenshot thumbnails (`NSFilePromiseReceiver`), or raw pasteboard images.
    public func extractURLsFromDraggingInfo(_ sender: NSDraggingInfo, completion: @escaping ([URL]) -> Void) {
        let pb = sender.draggingPasteboard

        // 1. macOS Floating Screenshot Preview (⌘⇧3 / ⌘⇧4 corner HUD uses NSFilePromiseReceiver!)
        if let promises = pb.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !promises.isEmpty {
            let destDir = screenshotStorageDirectory
            let group = DispatchGroup()
            var received: [URL] = []
            let lock = NSLock()

            for promise in promises {
                group.enter()
                promise.receivePromisedFiles(atDestination: destDir, options: [:], operationQueue: .main) { fileURL, error in
                    if error == nil {
                        lock.lock()
                        received.append(fileURL)
                        lock.unlock()
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) { [weak self] in
                if !received.isEmpty {
                    completion(received)
                } else if let fallbackImg = NSImage(pasteboard: pb),
                          let saved = self?.saveImageAsScreenshot(fallbackImg) {
                    completion([saved])
                } else {
                    completion([])
                }
            }
            return
        }

        // 2. Direct Finder / Desktop File URLs & NSFilenamesPboardType
        if let paths = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           !paths.isEmpty {
            let urls = paths.map { URL(fileURLWithPath: $0) }
            completion(urls)
            return
        }

        if let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !fileURLs.isEmpty {
            completion(fileURLs)
            return
        }

        // 3. Raw Image on Pasteboard (dragged from Safari/Chrome/Preview/Clipboard)
        if let pngData = pb.data(forType: .png), let saved = saveImageDataAsScreenshot(pngData, ext: "png") {
            completion([saved])
            return
        }
        if let tiffData = pb.data(forType: .tiff), let saved = saveImageDataAsScreenshot(tiffData, ext: "png") {
            completion([saved])
            return
        }
        if let img = NSImage(pasteboard: pb), let saved = saveImageAsScreenshot(img) {
            completion([saved])
            return
        }

        completion([])
    }

    /// Grabs either an image currently on the Clipboard (e.g. ⌘⌃⇧4) OR the newest screenshot file from macOS Screenshot folder / Desktop!
    public func grabLatestScreenshotFromClipboardOrDesktop() -> URL? {
        let pb = NSPasteboard.general

        // 1. If user copied a screenshot to Clipboard (⌘⌃⇧4), save it as a real PNG into Tray!
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            let ext = first.pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "heic", "webp", "tiff"].contains(ext) {
                return first
            }
        }
        if let png = pb.data(forType: .png), let saved = saveImageDataAsScreenshot(png, ext: "png") {
            return saved
        }
        if let tiff = pb.data(forType: .tiff), let saved = saveImageDataAsScreenshot(tiff, ext: "png") {
            return saved
        }

        // 2. Otherwise look for the newest screenshot in macOS screencapture location (defaults to ~/Desktop) + Downloads
        let customLoc = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        let folderURL: URL
        if let loc = customLoc, !loc.isEmpty {
            folderURL = URL(fileURLWithPath: (loc as NSString).expandingTildeInPath)
        } else {
            folderURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
        }

        var searchFolders = [folderURL]
        if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first, downloads != folderURL {
            searchFolders.append(downloads)
        }
        if let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
            let screenshotsFolder = pictures.appendingPathComponent("Screenshots")
            if FileManager.default.fileExists(atPath: screenshotsFolder.path) {
                searchFolders.append(screenshotsFolder)
            }
        }

        let screenshotKeywords = ["screenshot", "screen shot", "tangkap layar", "jepretan layar", "tangkapan layar", "screen recording"]
        var allCandidates: [URL] = []

        for folder in searchFolders {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            let candidates = files.filter { u in
                let ext = u.pathExtension.lowercased()
                guard ["png", "jpg", "jpeg", "heic", "tiff", "pdf"].contains(ext) else { return false }
                let lower = u.lastPathComponent.lowercased()
                return screenshotKeywords.contains(where: { lower.contains($0) })
            }
            allCandidates.append(contentsOf: candidates)
        }

        let newest = allCandidates.max { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }
        return newest
    }

    /// Copies BOTH the file URL and (for images) the NSImage pixels so ⌘V works in chat apps, browsers, AND Finder!
    public func copyItemToClipboard(_ item: DroppedItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if item.kind == .image, let img = NSImage(contentsOf: item.url) {
            pb.writeObjects([img, item.url as NSURL])
        } else {
            pb.writeObjects([item.url as NSURL])
        }
        NSSound(named: "Tink")?.play()
        showStatus("Disalin: \(item.name) — siap di-paste (⌘V)", outputURL: item.url)
    }

    public func refreshItem(_ id: UUID) {
        guard let idx = droppedItems.firstIndex(where: { $0.id == id }) else { return }
        let updated = inspectURL(droppedItems[idx].url, existingId: id)
        droppedItems[idx] = updated
        if activeStudioItem?.id == id {
            activeStudioItem = updated
        }
    }

    public func pickFilesFromFinder() {
        IslandState.shared.isModalOpen = true
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Pilih File atau PDF ke Tray"
        panel.prompt = "Masukkan ke Tray"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 5)

        panel.begin { [weak self] response in
            DispatchQueue.main.async {
                IslandState.shared.isModalOpen = false
                IslandController.shared.panel?.makeKeyAndOrderFront(nil)
                guard response == .OK, !panel.urls.isEmpty else { return }
                self?.addURLs(panel.urls)
                NSSound(named: "Pop")?.play()
            }
        }
    }

    public func openStudio(for item: DroppedItem) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            activeStudioItem = item
        }
    }

    public func closeStudio() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            activeStudioItem = nil
        }
    }

    public func removeItem(_ item: DroppedItem) {
        if activeStudioItem?.id == item.id {
            closeStudio()
        }
        droppedItems.removeAll { $0.id == item.id }
    }

    public func clearAll() {
        closeStudio()
        droppedItems.removeAll()
    }

    public func openItem(_ item: DroppedItem) {
        NSWorkspace.shared.open(item.url)
    }

    public func revealInFinder(_ item: DroppedItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    public func renameItem(_ item: DroppedItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let oldExt = item.url.pathExtension
        var finalName = trimmed
        if !oldExt.isEmpty && (trimmed as NSString).pathExtension.isEmpty {
            finalName = "\(trimmed).\(oldExt)"
        }

        let destURL = item.url.deletingLastPathComponent().appendingPathComponent(finalName)
        guard destURL != item.url else { return }

        do {
            try FileManager.default.moveItem(at: item.url, to: destURL)
            if let idx = droppedItems.firstIndex(where: { $0.id == item.id }) {
                let updated = inspectURL(destURL, existingId: item.id)
                droppedItems[idx] = updated
                if activeStudioItem?.id == item.id {
                    activeStudioItem = updated
                }
            }
            showStatus("Nama diubah ke \(finalName)", outputURL: destURL)
        } catch {
            showStatus("Gagal mengubah nama: \(error.localizedDescription)", outputURL: nil, isError: true)
        }
    }

    public func zipItems(_ items: [DroppedItem]) {
        guard let first = items.first else { return }
        isBusy = true
        let urls = items.map { $0.url }

        DispatchQueue.global(qos: .userInitiated).async {
            let baseDir = PDFStudioService.writableOutputDirectory(near: first.url)
            let baseName = items.count == 1 ? first.url.deletingPathExtension().lastPathComponent : "Arsip_Tray_\(items.count)_File"
            let zipURL = PDFStudioService.uniqueOutputURL(in: baseDir, baseName: baseName, ext: "zip")

            var ok = false
            if items.count == 1 {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                proc.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", first.url.path, zipURL.path]
                try? proc.run()
                proc.waitUntilExit()
                ok = (proc.terminationStatus == 0)
            } else {
                // Stage multiple files in temp dir then ditto
                let staging = FileManager.default.temporaryDirectory.appendingPathComponent("tray_zip_\(UUID().uuidString)")
                try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                for u in urls {
                    try? FileManager.default.copyItem(at: u, to: staging.appendingPathComponent(u.lastPathComponent))
                }
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                proc.arguments = ["-c", "-k", "--sequesterRsrc", staging.path, zipURL.path]
                try? proc.run()
                proc.waitUntilExit()
                ok = (proc.terminationStatus == 0)
                try? FileManager.default.removeItem(at: staging)
            }

            DispatchQueue.main.async {
                self.isBusy = false
                if ok {
                    self.addURLs([zipURL])
                    NSSound(named: "Glass")?.play()
                    self.showStatus("Berhasil dibuat: \(zipURL.lastPathComponent)", outputURL: zipURL)
                } else {
                    self.showStatus("Gagal membuat arsip ZIP", outputURL: nil, isError: true)
                }
            }
        }
    }

    public func showStatus(_ message: String, outputURL: URL?, isError: Bool = false) {
        bannerDismissWork?.cancel()
        statusBanner = TrayStatusBanner(message: message, outputURL: outputURL, isError: isError)
        if !isError {
            CapybaraService.shared.reactToEvent("udah siap diambil nih")
        }
        let work = DispatchWorkItem { [weak self] in
            self?.statusBanner = nil
        }
        bannerDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5, execute: work)
    }
}

import Foundation

public struct ScanTarget: Sendable {
    public let path: String
    public let isTopLevelDirectory: Bool // If true, scan each immediate child folder (like ~/Library/Caches/*); if false, scan this folder as single target (like DerivedData)

    public init(path: String, isTopLevelDirectory: Bool) {
        self.path = path
        self.isTopLevelDirectory = isTopLevelDirectory
    }
}

public final class ScannerService: Sendable {
    public static let shared = ScannerService()

    private var fileManager: FileManager { FileManager.default }
    private let knowledgeBase = KnowledgeBase.shared

    public init() {}

    /// Returns list of canonical whitelisted paths allowed for scanning and trashing.
    public func allowedBaseDirectories() -> [String] {
        let home = NSHomeDirectory()
        return [
            (home as NSString).appendingPathComponent("Library/Caches"),
            (home as NSString).appendingPathComponent("Library/Logs"),
            (home as NSString).appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            (home as NSString).appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
            (home as NSString).appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
            (home as NSString).appendingPathComponent(".npm/_cacache"),
            (home as NSString).appendingPathComponent(".cache"),
            (home as NSString).appendingPathComponent(".gradle/caches"),
            (home as NSString).appendingPathComponent(".cargo/registry/cache"),
            (home as NSString).appendingPathComponent(".cocoapods/cache")
        ]
    }

    /// Verifies if a given path is within strict allowed cache whitelist.
    public func isPathSafe(path: String) -> Bool {
        let standardPath = (path as NSString).standardizingPath
        let home = NSHomeDirectory()

        // 1. Strict blacklist of critical system & user directories
        let prohibitedPrefixes = [
            "/System", "/usr", "/bin", "/sbin", "/var", "/etc", "/Library", "/Applications",
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Desktop"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Pictures"),
            (home as NSString).appendingPathComponent("Movies"),
            (home as NSString).appendingPathComponent("Music"),
            (home as NSString).appendingPathComponent(".ssh"),
            (home as NSString).appendingPathComponent(".gnupg"),
            (home as NSString).appendingPathComponent(".aws")
        ]

        for prohibited in prohibitedPrefixes {
            if standardPath == prohibited || standardPath.hasPrefix(prohibited + "/") {
                return false
            }
        }

        // Never allow home directory itself or root
        if standardPath == "/" || standardPath == home || standardPath == (home as NSString).appendingPathComponent("Library") {
            return false
        }

        // 2. Must be within allowed whitelist
        let allowed = allowedBaseDirectories()
        for base in allowed {
            let standardBase = (base as NSString).standardizingPath
            if standardPath == standardBase || standardPath.hasPrefix(standardBase + "/") {
                return true
            }
        }

        return false
    }

    /// Asynchronously scans all configured cache targets.
    public func scan(
        onProgress: @escaping @Sendable (String) -> Void
    ) async -> [CacheItem] {
        let home = NSHomeDirectory()

        let targets: [ScanTarget] = [
            // User Caches (Scan immediate children)
            ScanTarget(path: (home as NSString).appendingPathComponent("Library/Caches"), isTopLevelDirectory: true),

            // Developer Artifacts (Specific targets)
            ScanTarget(path: (home as NSString).appendingPathComponent("Library/Developer/Xcode/DerivedData"), isTopLevelDirectory: false),
            ScanTarget(path: (home as NSString).appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"), isTopLevelDirectory: false),
            ScanTarget(path: (home as NSString).appendingPathComponent("Library/Developer/CoreSimulator/Caches"), isTopLevelDirectory: false),

            // Logs (Scan immediate children)
            ScanTarget(path: (home as NSString).appendingPathComponent("Library/Logs"), isTopLevelDirectory: true),

            // Package Caches
            ScanTarget(path: (home as NSString).appendingPathComponent(".npm/_cacache"), isTopLevelDirectory: false),
            ScanTarget(path: (home as NSString).appendingPathComponent(".cache"), isTopLevelDirectory: true),
            ScanTarget(path: (home as NSString).appendingPathComponent(".gradle/caches"), isTopLevelDirectory: false),
            ScanTarget(path: (home as NSString).appendingPathComponent(".cargo/registry/cache"), isTopLevelDirectory: false),
            ScanTarget(path: (home as NSString).appendingPathComponent(".cocoapods/cache"), isTopLevelDirectory: false)
        ]

        var discoveredItems: [CacheItem] = []
        var processedPaths = Set<String>()

        for target in targets {
            let targetURL = URL(fileURLWithPath: target.path)
            guard fileManager.fileExists(atPath: target.path) else { continue }

            if target.isTopLevelDirectory {
                // Scan immediate children of this directory
                guard let contents = try? fileManager.contentsOfDirectory(
                    at: targetURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for childURL in contents {
                    let childPath = childURL.path
                    guard !processedPaths.contains(childPath) else { continue }
                    guard isPathSafe(path: childPath) else { continue }

                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: childPath, isDirectory: &isDir), isDir.boolValue {
                        onProgress("Memindai \(childURL.lastPathComponent)...")
                        if let item = await scanSingleItem(url: childURL) {
                            if item.sizeInBytes > 0 {
                                discoveredItems.append(item)
                                processedPaths.insert(childPath)
                            }
                        }
                    }
                }
            } else {
                // Scan this specific folder as one item
                guard !processedPaths.contains(target.path) else { continue }
                guard isPathSafe(path: target.path) else { continue }

                onProgress("Memindai \(targetURL.lastPathComponent)...")
                if let item = await scanSingleItem(url: targetURL) {
                    if item.sizeInBytes > 0 {
                        discoveredItems.append(item)
                        processedPaths.insert(target.path)
                    }
                }
            }
        }

        // Sort by size descending by default
        return discoveredItems.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    /// Calculates size and gathers metadata for a specific cache folder.
    private func scanSingleItem(url: URL) async -> CacheItem? {
        let path = url.path
        let folderName = url.lastPathComponent

        // Calculate size in non-blocking manner
        let (totalBytes, fileCount, lastModified) = calculateDirectorySize(url: url)

        // Resolve metadata from KnowledgeBase
        let meta = knowledgeBase.resolve(folderName: folderName, fullPath: path)

        return CacheItem(
            name: meta.name,
            folderName: folderName,
            path: path,
            url: url,
            sizeInBytes: totalBytes,
            fileCount: fileCount,
            category: meta.category,
            riskLevel: meta.risk,
            contentDescription: meta.content,
            impactDescription: meta.impact,
            isSelected: meta.risk != .needsAttention, // Auto-select verySafe and safe, leave needsAttention unchecked for safety
            lastModified: lastModified
        )
    }

    /// Traverses directory calculating total byte size and file count.
    private func calculateDirectorySize(url: URL) -> (totalBytes: Int64, fileCount: Int, lastModified: Date?) {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return (0, 0, nil)
        }

        var totalSize: Int64 = 0
        var count = 0
        var latestDate: Date? = nil

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey, .isRegularFileKey]) else {
                continue
            }

            if resourceValues.isRegularFile == true {
                count += 1
                let size = resourceValues.totalFileAllocatedSize ?? resourceValues.fileSize ?? 0
                totalSize += Int64(size)
            }

            if let modDate = resourceValues.contentModificationDate {
                if latestDate == nil || modDate > latestDate! {
                    latestDate = modDate
                }
            }
        }

        return (totalSize, count, latestDate)
    }
}

import Foundation
import AppKit

public struct CleaningResult: Sendable {
    public let totalBytesFreed: Int64
    public let successfulItems: [CacheItem]
    public let failedItems: [(item: CacheItem, error: String)]

    public var hasFailures: Bool {
        !failedItems.isEmpty
    }

    public var formattedTotalFreed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytesFreed)
    }
}

public final class CleanerService: Sendable {
    public static let shared = CleanerService()

    private let scannerService = ScannerService.shared

    public init() {}

    /// Safely recycles the selected cache items to macOS Trash.
    /// Does NOT perform permanent deletion (rm -rf).
    public func cleanItems(
        _ items: [CacheItem],
        onProgress: @escaping @Sendable (CacheItem, Int, Int) -> Void
    ) async -> CleaningResult {
        var totalFreed: Int64 = 0
        var successList: [CacheItem] = []
        var failureList: [(item: CacheItem, error: String)] = []

        let totalCount = items.count

        for (index, item) in items.enumerated() {
            onProgress(item, index + 1, totalCount)

            // 1. Strict Path Whitelist Verification
            guard scannerService.isPathSafe(path: item.path) else {
                failureList.append((item, "Dibatalkan: Path di luar batas aman yang diizinkan."))
                continue
            }

            guard FileManager.default.fileExists(atPath: item.path) else {
                // Folder might have been deleted already or empty
                continue
            }

            // 2. Perform safe move to macOS Trash
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &trashedURL)
                totalFreed += item.sizeInBytes
                successList.append(item)
            } catch {
                let errDesc = error.localizedDescription
                // Graceful error handling for locked files (in-use) or permission restrictions
                failureList.append((item, "Gagal memindahkan ke Sampah: \(errDesc)"))
            }
        }

        return CleaningResult(
            totalBytesFreed: totalFreed,
            successfulItems: successList,
            failedItems: failureList
        )
    }
}

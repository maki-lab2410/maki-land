import Foundation
import SwiftUI
import Combine

public final class CacheCleanerManager: ObservableObject {
    public static let shared = CacheCleanerManager()

    @Published public var items: [CacheItem] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var progressText: String = ""
    @Published public var totalSafeBytes: Int64 = 0
    @Published public var totalAllBytes: Int64 = 0
    @Published public var lastFreedBytes: Int64 = 0
    @Published public var lastCleanResult: CleaningResult? = nil
    @Published public var hasCompletedInitialScan: Bool = false

    private let scanner = ScannerService.shared
    private let cleaner = CleanerService.shared
    private let history = HistoryService.shared

    private init() {
        // Quick background scan shortly after app starts
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await self?.startScan()
        }
    }

    public var safeItems: [CacheItem] {
        items.filter { $0.riskLevel != .needsAttention }
    }

    public var formattedTotalSafeSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSafeBytes)
    }

    public var formattedTotalAllSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalAllBytes)
    }

    @MainActor
    public func startScan() async {
        guard !isScanning && !isCleaning else { return }
        isScanning = true
        progressText = "Mencari cache..."

        let scanned = await scanner.scan { [weak self] status in
            Task { @MainActor in
                self?.progressText = status
            }
        }

        self.items = scanned
        var safeSum: Int64 = 0
        var allSum: Int64 = 0
        for item in scanned {
            allSum += item.sizeInBytes
            if item.riskLevel != .needsAttention {
                safeSum += item.sizeInBytes
            }
        }
        self.totalSafeBytes = safeSum
        self.totalAllBytes = allSum
        self.isScanning = false
        self.hasCompletedInitialScan = true
        self.progressText = ""
    }

    /// Cleans all safe cache items (moving them to macOS Trash)
    @MainActor
    public func cleanSafeItems(
        onComplete: (@Sendable (CleaningResult) -> Void)? = nil
    ) async -> CleaningResult {
        let target = self.safeItems
        guard !target.isEmpty else {
            let emptyResult = CleaningResult(totalBytesFreed: 0, successfulItems: [], failedItems: [])
            onComplete?(emptyResult)
            return emptyResult
        }

        isCleaning = true
        progressText = "Membersihkan cache..."

        let result = await cleaner.cleanItems(target) { [weak self] item, cur, total in
            Task { @MainActor in
                self?.progressText = "Memindahkan \(cur)/\(total): \(item.name)"
            }
        }

        self.lastCleanResult = result
        self.lastFreedBytes = result.totalBytesFreed
        self.isCleaning = false
        self.progressText = ""

        // Refresh list after cleaning
        await startScan()

        onComplete?(result)
        return result
    }
}

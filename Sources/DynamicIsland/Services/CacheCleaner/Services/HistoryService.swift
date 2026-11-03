import Foundation

public final class HistoryService: Sendable {
    public static let shared = HistoryService()

    private var fileManager: FileManager { FileManager.default }

    private var historyFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let makiDir = appSupport.appendingPathComponent("MakiCacheCleaner", isDirectory: true)
        if !fileManager.fileExists(atPath: makiDir.path) {
            try? fileManager.createDirectory(at: makiDir, withIntermediateDirectories: true)
        }
        return makiDir.appendingPathComponent("history.json")
    }

    public init() {}

    public func loadHistory() -> [CleaningLog] {
        let url = historyFileURL
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CleaningLog].self, from: data)) ?? []
    }

    public func recordCleaning(result: CleaningResult) -> CleaningLog {
        var records: [CleanedItemRecord] = []

        for item in result.successfulItems {
            records.append(CleanedItemRecord(
                name: item.name,
                path: item.abbreviatedPath,
                sizeInBytes: item.sizeInBytes,
                status: "Berhasil dipindahkan ke Sampah"
            ))
        }

        for (item, err) in result.failedItems {
            records.append(CleanedItemRecord(
                name: item.name,
                path: item.abbreviatedPath,
                sizeInBytes: item.sizeInBytes,
                status: "Gagal: \(err)"
            ))
        }

        let log = CleaningLog(
            timestamp: Date(),
            totalBytesFreed: result.totalBytesFreed,
            itemsCount: result.successfulItems.count,
            items: records
        )

        var existing = loadHistory()
        existing.insert(log, at: 0) // newest first

        // Keep last 100 sessions
        if existing.count > 100 {
            existing = Array(existing.prefix(100))
        }

        saveHistory(existing)
        return log
    }

    private func saveHistory(_ logs: [CleaningLog]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(logs) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }

    public func clearHistory() {
        let url = historyFileURL
        try? fileManager.removeItem(at: url)
    }
}

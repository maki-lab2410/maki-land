import Foundation

public struct CleanedItemRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public let sizeInBytes: Int64
    public let status: String // "Berhasil dipindahkan ke Trash" or "Gagal: ..."

    public init(id: UUID = UUID(), name: String, path: String, sizeInBytes: Int64, status: String) {
        self.id = id
        self.name = name
        self.path = path
        self.sizeInBytes = sizeInBytes
        self.status = status
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }
}

public struct CleaningLog: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let totalBytesFreed: Int64
    public let itemsCount: Int
    public let items: [CleanedItemRecord]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        totalBytesFreed: Int64,
        itemsCount: Int,
        items: [CleanedItemRecord]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.totalBytesFreed = totalBytesFreed
        self.itemsCount = itemsCount
        self.items = items
    }

    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    public var formattedTotalFreed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytesFreed)
    }
}

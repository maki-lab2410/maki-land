import Foundation

public struct CacheItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let folderName: String
    public let path: String
    public let url: URL
    public var sizeInBytes: Int64
    public let fileCount: Int
    public let category: CacheCategory
    public let riskLevel: RiskLevel
    public let contentDescription: String
    public let impactDescription: String
    public var isSelected: Bool
    public let lastModified: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        folderName: String,
        path: String,
        url: URL,
        sizeInBytes: Int64,
        fileCount: Int = 0,
        category: CacheCategory,
        riskLevel: RiskLevel,
        contentDescription: String,
        impactDescription: String,
        isSelected: Bool = true,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.folderName = folderName
        self.path = path
        self.url = url
        self.sizeInBytes = sizeInBytes
        self.fileCount = fileCount
        self.category = category
        self.riskLevel = riskLevel
        self.contentDescription = contentDescription
        self.impactDescription = impactDescription
        self.isSelected = isSelected
        self.lastModified = lastModified
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }

    public var abbreviatedPath: String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    public static func == (lhs: CacheItem, rhs: CacheItem) -> Bool {
        lhs.path == rhs.path
    }
}

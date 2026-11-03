import SwiftUI

public enum CacheCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case developer = "Developer & Build"
    case browsers = "Web Browsers"
    case mediaStreaming = "Media & Streaming"
    case communication = "Komunikasi & Chat"
    case systemLogs = "System & App Logs"
    case packageManagers = "Package Managers"
    case utilities = "Utilities & Tools"
    case general = "Aplikasi Lainnya"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .developer:
            return "hammer.fill"
        case .browsers:
            return "globe"
        case .mediaStreaming:
            return "play.tv.fill"
        case .communication:
            return "bubble.left.and.bubble.right.fill"
        case .systemLogs:
            return "doc.text.magnifyingglass"
        case .packageManagers:
            return "shippingbox.fill"
        case .utilities:
            return "gearshape.2.fill"
        case .general:
            return "app.badge.fill"
        }
    }

    public var color: Color {
        switch self {
        case .developer:
            return .purple
        case .browsers:
            return .blue
        case .mediaStreaming:
            return .pink
        case .communication:
            return .teal
        case .systemLogs:
            return .brown
        case .packageManagers:
            return .orange
        case .utilities:
            return .gray
        case .general:
            return .indigo
        }
    }
}

import SwiftUI

public enum RiskLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case verySafe = "Sangat Aman"
    case safe = "Aman"
    case needsAttention = "Perlu Perhatian"

    public var id: String { rawValue }

    public var title: String {
        rawValue
    }

    public var badgeColor: Color {
        switch self {
        case .verySafe:
            return .green
        case .safe:
            return .blue
        case .needsAttention:
            return .orange
        }
    }

    public var iconName: String {
        switch self {
        case .verySafe:
            return "checkmark.shield.fill"
        case .safe:
            return "shield.fill"
        case .needsAttention:
            return "exclamationmark.shield.fill"
        }
    }

    public var shortDescription: String {
        switch self {
        case .verySafe:
            return "File murni sementara/build artifact. Sangat aman dibersihkan tanpa gangguan bagi pengguna."
        case .safe:
            return "File cache aplikasi umum. Aplikasi akan membuat ulang otomatis saat dibuka kembali."
        case .needsAttention:
            return "Dapat membutuhkan waktu download ulang atau re-ekstraksi simbol saat digunakan berikutnya."
        }
    }

    public var sortPriority: Int {
        switch self {
        case .verySafe: return 0
        case .safe: return 1
        case .needsAttention: return 2
        }
    }
}

import SwiftUI
import AppKit

public struct UpdateDialogView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var updater = UpdateService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.20))
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Pembaruan makiland Tersedia!")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("v\(updater.latestVersion)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.green.opacity(0.25))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }

                    Text("Versi kamu: v\(updater.currentVersion) • Rilis resmi GitHub")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.white.opacity(0.60))
                }

                Spacer()

                if !updater.isDownloading && !updater.isInstallingUpdate {
                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                            state.isShowingUpdateModal = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.40))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Body: Downloading Progress OR Release Notes
            if updater.isDownloading || updater.isInstallingUpdate {
                VStack(spacing: 7) {
                    HStack {
                        Text(updater.installStatusText.isEmpty ? "Mengunduh pembaruan..." : updater.installStatusText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 7)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Color.mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * CGFloat(updater.downloadProgress)), height: 7)
                                .animation(.linear(duration: 0.18), value: updater.downloadProgress)
                        }
                    }
                    .frame(height: 7)

                    HStack {
                        Text("Aplikasi akan otomatis diganti ke versi terbaru dan dimulai ulang.")
                            .font(.system(size: 8.8, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                        Spacer()
                        if updater.isDownloading {
                            Button {
                                updater.cancelUpdate()
                            } label: {
                                Text("Batal")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(.red.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(9)
                .frame(maxHeight: 90)
            } else if let error = updater.updateError {
                // Error state
                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 9.2, design: .rounded))
                            .foregroundColor(.orange.opacity(0.95))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Button {
                            updater.start1ClickAutoUpdate()
                        } label: {
                            Text("Coba Lagi")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.20))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            updater.openReleaseOrDownload()
                        } label: {
                            Text("Buka Browser ↗")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.10))
                                .foregroundColor(.white.opacity(0.80))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.red.opacity(0.12))
                .cornerRadius(8)
                .frame(maxHeight: 90)
            } else {
                // Release Notes Card
                if !updater.releaseNotes.isEmpty {
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(updater.releaseNotes)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(2)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 90)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                } else {
                    Text("Pembaruan ini mencakup peningkatan performa, perbaikan tampilan, dan fitur terbaru.")
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.70))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            }

            // Action Row
            HStack(spacing: 10) {
                if !updater.isDownloading && !updater.isInstallingUpdate {
                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                            state.isShowingUpdateModal = false
                        }
                    } label: {
                        Text("Nanti Saja")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white.opacity(0.75))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        updater.openReleaseOrDownload()
                    } label: {
                        Text("Unduh Manual ↗")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .help("Buka link unduhan di browser GitHub jika ingin mengunduh manual")

                    Spacer()

                    // 1-Click In-App Auto Update Button!
                    Button {
                        updater.start1ClickAutoUpdate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("✨ Perbarui Otomatis (1-Klik)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5.5)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.green.opacity(0.35), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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
                        Text("Pembaruan maki-land Tersedia!")
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

                    Text("Versi saat ini: v\(updater.currentVersion) • Rilis resmi GitHub")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.white.opacity(0.60))
                }

                Spacer()

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

            // Action Row
            HStack(spacing: 10) {
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

                Spacer()

                Button {
                    updater.openReleaseOrDownload()
                    withAnimation {
                        state.isShowingUpdateModal = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Unduh & Perbarui Sekarang")
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
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
